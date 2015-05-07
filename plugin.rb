# name: discourse-sketchup-sso
# about: Sketchup SSO support
# version: 0.1
# authors: Sam Saffron

class SketchupAuthenticator < Auth::OpenIdAuthenticator

  def after_authenticate(auth_token)
    result = super(auth_token)
    #info = auth_token[:info]

    # For now lets debug the info in /logs, we can remove later
    # Rails.logger.warn("OpenID reply recieved" << info.inspect)

    if result.email.present? && result.user.present?
      result.user.update_columns(email: result.email)
    end

    result
  end

end

url = Rails.env.development? ? 'https://dev-accounts.sketchup.com/openid/provider' :
                               'https://accounts.sketchup.com/openid/provider'

auth_provider :title => 'with Sketchup',
              :authenticator => SketchupAuthenticator.new(
                'sketchup', url,
                trusted: true),
              :message => 'Authenticating with Sketchup (make sure pop up blockers are not enabled)',
              :frame_width => 1000,   # the frame size used for the pop up window, overrides default
              :frame_height => 800


register_css <<CSS
.btn-social.sketchup {
  background: #00b;
}

CSS
