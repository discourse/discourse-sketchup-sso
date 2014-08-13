# name: discourse-sketchup-sso
# about: Sketchup SSO support
# version: 0.1
# authors: Sam Saffron

auth_provider :title => 'with Sketchup',
              :authenticator => Auth::OpenIdAuthenticator.new(
                'sketchup','https://accounts.sketchup.com/openid/provider',
                trusted: true),
              :message => 'Authenticating with Sketchup (make sure pop up blockers are not enabled)',
              :frame_width => 1000,   # the frame size used for the pop up window, overrides default
              :frame_height => 800


register_css <<CSS
.btn-social.ubuntu {
  background: #00b;
}

CSS
