describe Spree::Gateway::PayPalExpress do
  let(:payment_method) { Spree::Gateway::PayPalExpress.create!(name: "PayPalExpress") }

  context "payment purchase" do
    let(:payment) do
      payment = create(:payment, payment_method: payment_method, amount: 10)
      allow(payment).to receive_messages source: mock_model(Spree::PaypalExpressCheckout, token: 'fake_token', payer_id: 'fake_payer_id', update: true)
      payment
    end

    let(:gateway) do
      gateway = double('gateway')
      allow(payment_method).to receive_messages(gateway: gateway)
      gateway
    end

    before do
      expect(gateway).
        to receive(:build_get_express_checkout_details).
        with({Token: 'fake_token'}).
        and_return(pp_details_request = double)

      pp_details_response = double(
        get_express_checkout_details_response_details: double(
          PaymentDetails: {
            OrderTotal: {
              currencyID: "USD",
              value: "10.00"
            }}))

      expect(gateway).to receive(:get_express_checkout_details).
        with(pp_details_request).
        and_return(pp_details_response)

      expect(gateway).
        to receive(:build_do_express_checkout_payment).
        with(
          { DoExpressCheckoutPaymentRequestDetails: {
            PaymentAction: "Authorization",
            Token: "fake_token",
            PayerID: "fake_payer_id",
            PaymentDetails: pp_details_response.get_express_checkout_details_response_details.PaymentDetails
          }})
    end

    # Test for #11
    it "succeeds" do
      response = double(
        'pp_response',
        success?: true,
        to_hash: {},
        errors: []
      )
      allow(response).
        to receive_message_chain("do_express_checkout_payment_response_details.payment_info.first.transaction_id").and_return '12345'
      expect(gateway).
        to receive(:do_express_checkout_payment).
        and_return(response)

      payment.authorize!
    end

    # Test for #4
    it "fails" do
      response = double(
        'pp_response',
        success?: false,
        to_hash: {},
        errors: [
          double('pp_response_error', long_message: "An error goes here.")])

      allow(response).
        to receive_message_chain("do_express_checkout_payment_response_details.payment_info.first.transaction_id").and_return '12345'

      expect(gateway).to receive(:do_express_checkout_payment).and_return(response)

      expect { payment.authorize! }.
        to raise_error(Spree::Core::GatewayError)
    end
  end
end
