FactoryGirl.define do
  factory :spree_gateway_pay_pal_express,
          class: "Spree::Gateway::PayPalExpress" do
    preferred_login "solidus-buyer_api1.example.com"
    preferred_password "57YMDWBYCDGS53QB"
    preferred_signature "AFcWxV21C7fd0v3bYYYRCpSSRl31AFPx.K2zvoXaQZLBnjHSCn0U9epw"
    preferred_use_new_layout true
    name "PayPal"
    active true
  end
end
