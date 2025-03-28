# frozen_string_literal: true
# name: discourse-sketchup-sso
# about: Sketchup SSO support
# version: 0.2
# authors: Sam Saffron, Roy Chanley

require "multi_json"

class SketchupAuthenticator < ::Auth::Authenticator
  def name
    "sketchup"
  end

  def register_middleware(omniauth)
    omniauth.provider :sketchup,
                      setup:
                        lambda { |env|
                          opts = env["omniauth.strategy"].options
                          opts[:authorize_url] = SiteSetting.sketchup_authorize_url
                          opts[:sso_cookie_name] = SiteSetting.sketchup_sso_cookie_name
                          opts[:userinfo_url] = SiteSetting.sketchup_userinfo_url
                        }
  end

  def after_authenticate(auth_token)
    result = Auth::Result.new

    result.email = email = auth_token[:info][:email]
    raise Discourse::InvalidParameters.new(:email) if email.empty?

    result.email_valid = true
    result.user = User.find_by_email(email)
    result
  end

  def enabled?
    true
  end
end

class OmniAuth::Strategies::Sketchup
  include OmniAuth::Strategy

  option :name, "sketchup"
  option :authorize_url, ""
  option :sso_cookie_name, ""
  option :userinfo_url, ""

  uid { @auth_data["trimbleid"] }

  info do
    {
      name: "#{@auth_data["firstname"]} #{@auth_data["lastname"]}",
      email: @auth_data["email"],
      first_name: @auth_data["firstname"],
      last_name: @auth_data["lastname"],
    }
  end

  extra { { raw_info: @auth_data } }

  def request_phase
    redirect(options.authorize_url)
  end

  def callback_phase
    request = Rack::Request.new(env)

    # Use the cookie from the request phase and query the userinfo URL.
    # Note that if the cookie isn't part of the request above, it's likely
    # because you're not on a sketchup.com domain (and thus this will be broken).
    if request.cookies.has_key?(options.sso_cookie_name)
      response =
        Excon.get(
          options.userinfo_url,
          headers: {
            Authorization: request.cookies[options.sso_cookie_name].tr('"', ""),
          },
        )

      @auth_data = MultiJson.decode(response.body.to_s)
      super
    else
      fail!(:invalid_request)
    end
  rescue StandardError => e
    fail!(:invalid_response, e)
  end
end

auth_provider title: "with SketchUp",
              frame_width: 725,
              frame_height: 600,
              authenticator: SketchupAuthenticator.new

register_asset "stylesheets/common.scss"
