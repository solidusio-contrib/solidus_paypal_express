require "spec_helper"

describe Spree::PaypalController do
  routes { Spree::Core::Engine.routes }

  shared_context "current order is nil" do
    # Regression tests for #55
    context "when current_order is nil" do
      before do
        allow(controller).to receive(:current_order).
          and_return(nil)
        allow(controller).to receive(:current_spree_user).
          and_return(nil)
      end

      it "raises ActiveRecord::RecordNotFound" do
        expect{ subject }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "GET express" do
    subject { get :express }
    include_context "current order is nil"
  end

  describe "GET confirm" do
    subject { get :confirm }
    include_context "current order is nil"
  end

  describe "GET cancel" do
    subject { get :cancel }
    include_context "current order is nil"
  end
end
