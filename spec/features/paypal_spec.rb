describe "PayPal", js: true, type: :feature do
  let!(:product) { create(:product, name: 'iPad') }
  let!(:gateway) { create(:spree_gateway_pay_pal_express) }
  let!(:shipping_method) { create(:shipping_method) }
  let(:new_payment) { Spree::Payment.last }
  let(:new_order) { Spree::Order.last }
  let!(:store) { create(:store) }

  before { expire_cookies }

  it "Completes an order with PayPal Express" do
    visit spree.root_path
    click_link 'iPad'
    click_button 'Add To Cart'
    click_button 'Checkout'

    fill_in_billing
    click_button "Save and Continue"
    # Delivery step doesn't require any action
    click_button "Save and Continue"
    find("#paypal_button").click

    login_to_paypal

    has_selector?(".preloader .spinner", visible: false)
    sleep 5 # TODO: Get rid of this sleep and find things the right way
    click_button "Pay Now", match: :first

    expect {
      click_button "Place Order"
    }.to change {
      Spree::Payment.count
    }.by(1)

    expect(new_order).to be_complete
    expect(new_payment.transaction_id).to_not be_blank
    expect(new_payment).to be_pending

    new_payment.capture!

    expect(new_payment).to be_completed

    expect {
      new_payment.refunds.create(
        refund_reason_id: create(:refund_reason).id,
        amount: new_payment.amount)
    }.to change {
      new_payment.refunds.count
    }.by(1)
  end

  context "with 'Sole' solution type" do
    before do
      gateway.preferred_solution = 'Sole'
    end

    xit "passes user details to PayPal" do
      visit spree.root_path
      click_link 'iPad'
      click_button 'Add To Cart'
      click_button 'Checkout'
      within("#guest_checkout") do
        fill_in "Email", with: "test@example.com"
        click_button 'Continue'
      end
      fill_in_billing
      click_button "Save and Continue"
      # Delivery step doesn't require any action
      click_button "Save and Continue"
      find("#paypal_button").click

      login_to_paypal
      click_button "Pay Now"

      expect(page).to have_selector '[data-hook=order-bill-address] .fn', text: 'Test User'
      expect(page).to have_selector '[data-hook=order-bill-address] .adr', text: '1 User Lane'
      expect(page).to have_selector '[data-hook=order-bill-address] .adr', text: 'Adamsville AL 35005'
      expect(page).to have_selector '[data-hook=order-bill-address] .adr', text: 'United States'
      expect(page).to have_selector '[data-hook=order-bill-address] .tel', text: '555-123-4567'
    end
  end

  xit "includes adjustments in PayPal summary" do
    visit spree.root_path
    click_link 'iPad'
    click_button 'Add To Cart'
    # TODO: Is there a better way to find this current order?
    order = Spree::Order.last
    order.adjustments.create!(amount: -5, label: "$5 off")
    order.adjustments.create!(amount: 10, label: "$10 on")
    visit '/cart'
    within("#cart_adjustments") do
      expect(page).to have_content("$5 off")
      expect(page).to have_content("$10 on")
    end
    click_button 'Checkout'
    within("#guest_checkout") do
      fill_in "Email", with: "test@example.com"
      click_button 'Continue'
    end
    fill_in_billing
    click_button "Save and Continue"
    # Delivery step doesn't require any action
    click_button "Save and Continue"
    find("#paypal_button").click

    within_transaction_cart do
      expect(page).to have_content("$5 off")
      expect(page).to have_content("$10 on")
    end

    login_to_paypal

    within_transaction_cart do
      expect(page).to have_content("$5 off")
      expect(page).to have_content("$10 on")
    end

    click_button "Pay Now"

    within("[data-hook=order_details_adjustments]") do
      expect(page).to have_content("$5 off")
      expect(page).to have_content("$10 on")
    end
  end

  context "line item adjustments" do
    let(:promotion) { Spree::Promotion.create(name: "10% off") }
    before do
      calculator = Spree::Calculator::FlatPercentItemTotal.new(preferred_flat_percent: 10)
      action = Spree::Promotion::Actions::CreateItemAdjustments.create(calculator: calculator)
      promotion.actions << action
    end

    xit "includes line item adjustments in PayPal summary" do
      visit spree.root_path
      click_link 'iPad'
      click_button 'Add To Cart'
      # TODO: Is there a better way to find this current order?
      order = Spree::Order.last
      expect(order.line_item_adjustments.count).to eq(1)

      visit '/cart'
      within("#cart_adjustments") do
        expect(page).to have_content("10% off")
      end
      click_button 'Checkout'
      within("#guest_checkout") do
        fill_in "Email", with: "test@example.com"
        click_button 'Continue'
      end
      fill_in_billing
      click_button "Save and Continue"
      # Delivery step doesn't require any action
      click_button "Save and Continue"
      find("#paypal_button").click

      within_transaction_cart do
        expect(page).to have_content("10% off")
      end

      login_to_paypal
      click_button "Pay Now"

      within("[data-hook=order_details_price_adjustments]") do
        expect(page).to have_content("10% off")
      end
    end
  end

  # Regression test for #10
  context "will skip $0 items" do
    let!(:product2) { create(:product, name: 'iPod') }

    xit do
      visit spree.root_path
      click_link 'iPad'
      click_button 'Add To Cart'

      visit spree.root_path
      click_link 'iPod'
      click_button 'Add To Cart'

      # TODO: Is there a better way to find this current order?
      order = Spree::Order.last
      order.line_items.last.update_attribute(:price, 0)
      click_button 'Checkout'
      within("#guest_checkout") do
        fill_in "Email", with: "test@example.com"
        click_button 'Continue'
      end
      fill_in_billing
      click_button "Save and Continue"
      # Delivery step doesn't require any action
      click_button "Save and Continue"
      find("#paypal_button").click

      within_transaction_cart do
        expect(page).to have_content('iPad')
        expect(page).not_to have_content('iPod')
      end

      login_to_paypal

      within_transaction_cart do
        expect(page).to have_content('iPad')
        expect(page).not_to have_content('iPod')
      end

      click_button "Pay Now"

      within("#line-items") do
        expect(page).to have_content('iPad')
        expect(page).to have_content('iPod')
      end
    end
  end

  context "can process an order with $0 item total" do
    before do
      # If we didn't do this then the order would be free and skip payment altogether
      calculator = Spree::ShippingMethod.first.calculator
      calculator.preferred_amount = 10
      calculator.save
    end

    xit do
      visit spree.root_path
      click_link 'iPad'
      click_button 'Add To Cart'
      # TODO: Is there a better way to find this current order?
      order = Spree::Order.last
      order.adjustments.create!(amount: -order.line_items.last.price, label: "FREE iPad ZOMG!")
      click_button 'Checkout'
      within("#guest_checkout") do
        fill_in "Email", with: "test@example.com"
        click_button 'Continue'
      end
      fill_in_billing
      click_button "Save and Continue"
      # Delivery step doesn't require any action
      click_button "Save and Continue"
      find("#paypal_button").click

      login_to_paypal

      click_button "Pay Now"

      within("[data-hook=order_details_adjustments]") do
        expect(page).to have_content('FREE iPad ZOMG!')
      end
    end
  end

  context "cannot process a payment with invalid gateway details" do
    before do
      gateway.preferred_login = nil
      gateway.save
    end

    specify do
      visit spree.root_path
      click_link 'iPad'
      click_button 'Add To Cart'
      click_button 'Checkout'
      fill_in_billing
      click_button "Save and Continue"
      # Delivery step doesn't require any action
      click_button "Save and Continue"
      find("#paypal_button").click
      expect(page).to have_content("PayPal failed. Security header is not valid")
    end
  end

  context "as an admin" do
    stub_authorization!

    context "refunding payments" do
      before do
        visit spree.root_path
        click_link 'iPad'
        click_button 'Add To Cart'
        click_button 'Checkout'
        within("#guest_checkout") do
          fill_in "Email", with: "test@example.com"
          click_button 'Continue'
        end
        fill_in_billing
        click_button "Save and Continue"
        # Delivery step doesn't require any action
        click_button "Save and Continue"
        find("#paypal_button").click
        switch_to_paypal_login
        login_to_paypal
        click_button("Pay Now")
        expect(page).to have_content("Your order has been processed successfully")

        visit '/admin'
        click_link Spree::Order.last.number
        click_link "Payments"
        find("#content").find("table").first("a").click # this clicks the first payment
        click_link "Refund"
      end

      xit "can refund payments fully" do
        click_button "Refund"
        expect(page).to have_content("PayPal refund successful")

        payment = Spree::Payment.last
        paypal_checkout = payment.source.source
        expect(paypal_checkout.refund_transaction_id).not_to be_blank
        expect(paypal_checkout.refunded_at).not_to be_blank
        expect(paypal_checkout.state).to eql("refunded")
        expect(paypal_checkout.refund_type).to eql("Full")

        # regression test for #82
        within("table") do
          expect(page).to have_content(payment.display_amount.to_html)
        end
      end

      xit "can refund payments partially" do
        payment = Spree::Payment.last
        # Take a dollar off, which should cause refund type to be...
        fill_in "Amount", with: payment.amount - 1
        click_button "Refund"
        expect(page).to have_content("PayPal refund successful")

        source = payment.source
        expect(source.refund_transaction_id).not_to be_blank
        expect(source.refunded_at).not_to be_blank
        expect(source.state).to eql("refunded")
        # ... a partial refund
        expect(source.refund_type).to eql("Partial")
      end

      xit "errors when given an invalid refund amount" do
        fill_in "Amount", with: "lol"
        click_button "Refund"
        expect(page).to have_content("PayPal refund unsuccessful (The partial refund amount is not valid)")
      end
    end
  end

  def fill_in_billing
    fill_in "Customer E-Mail", with: "solidus-test@example.com"
    within("#billing") do
      fill_in "First Name", with: "Test"
      fill_in "Last Name", with: "User"
      fill_in "Street Address", with: "1 User Lane"
      # City, State and ZIP must all match for PayPal to be happy
      fill_in "City", with: "Adamsville"
      select "United States of America", from: "order_bill_address_attributes_country_id"
      select "Alabama", from: "order_bill_address_attributes_state_id"
      fill_in "Zip", with: "35005"
      fill_in "Phone", with: "555-123-4567"
    end
  end

  def switch_to_paypal_login
    # If you go through a payment once in the sandbox, it remembers your preferred setting.
    # It defaults to the *wrong* setting for the first time, so we need to have this method.
    unless page.has_selector?("#login #email")
      find("#loadLogin").click
    end
  end

  def login_to_paypal
    iframe = find('iframe[name="injectedUl"]')
    within_frame(iframe) do
      fill_in "Email", with: "solidus-test@example.com"
      fill_in "Password", with: "spree1234"
      click_button "Log In"
    end
  end

  def within_transaction_cart(&block)
    find(".transactionDetails").click
    within(".transctionCartDetails") { block.call }
  end
end
