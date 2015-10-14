RSpec.describe Spree::Gateway::PayPalExpress do
  describe ".express_checkout_url" do

    shared_context "gateway setup" do |token, use_new_layout, server|
      subject { payment_method.express_checkout_url(pp_response, {}) }

      let(:pp_response) { OpenStruct.new(Token: token) }

      let(:payment_method) {
        described_class.new(
          preferred_server: server,
          preferred_use_new_layout: use_new_layout
        )
      }
    end

    context "live server and old layout is preferred" do
      include_context "gateway setup", "1234", false, "live"

      it "returns the expected url" do
        expect(subject).to eq(
          "https://www.paypal.com/cgi-bin/webscr?" +
          "cmd=_express-checkout&force_sa=true&token=1234")
      end
    end

    context "sandbox server and old layout is preferred" do
      include_context "gateway setup", "1234", false, "sandbox"

      it "returns the expected url" do
        expect(subject).to eq(
          "https://www.sandbox.paypal.com/cgi-bin/webscr?" +
          "cmd=_express-checkout&force_sa=true&token=1234")
      end
    end

    context "live server and new layout is preferred" do
      include_context "gateway setup", "1234", true, "live"

      it "returns the expected url" do
        expect(subject).to eq(
          "https://www.paypal.com/checkoutnow/2?token=1234")
      end
    end

    context "sandbox server and new layout is preferred" do
      include_context "gateway setup", "1234", true, "sandbox"

      it "returns the expected url" do
        expect(subject).to eq(
          "https://www.sandbox.paypal.com/checkoutnow/2?token=1234")
      end
    end
  end
end
