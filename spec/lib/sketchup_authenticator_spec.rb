# frozen_string_literal: true

RSpec.describe "SketchupAuthenticator" do
  subject(:authenticator) { Discourse.authenticators.find { |auth| auth.name == "sketchup" } }

  it "enables login with the default endpoints and cookie name" do
    expect(authenticator.enabled?).to eq(true)
  end

  %i[sketchup_authorize_url sketchup_sso_cookie_name sketchup_userinfo_url].each do |setting|
    it "disables login when #{setting} is cleared" do
      SiteSetting.public_send("#{setting}=", "")

      expect(authenticator.enabled?).to eq(false)
    end
  end
end
