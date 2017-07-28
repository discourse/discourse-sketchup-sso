# name: discourse-sketchup-sso
# about: Sketchup SSO support
# version: 0.2
# authors: Sam Saffron, Roy Chanley

require 'multi_json'

class SketchupAuthenticator < ::Auth::Authenticator

  def name
    "sketchup"
  end

  def register_middleware(omniauth)
    omniauth.provider :sketchup,
      setup: lambda { |env|
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
end

class OmniAuth::Strategies::Sketchup
  include OmniAuth::Strategy

  option :name, 'sketchup'
  option :authorize_url, ''
  option :sso_cookie_name, ''
  option :userinfo_url, ''

  uid do
    @auth_data['trimbleid']
  end

  info do
    {
      name: "#{@auth_data['firstname']} #{@auth_data['lastname']}",
      email: @auth_data['email'],
      first_name: @auth_data['firstname'],
      last_name: @auth_data['lastname']
    }
  end

  extra do
    {
      raw_info: @auth_data
    }
  end

  def request_phase
    redirect(options.authorize_url)
  end

  def callback_phase
    request = Rack::Request.new(env)

    # Use the cookie from the request phase and query the userinfo URL.
    # Note that if the cookie isn't part of the request above, it's likely
    # because you're not on a sketchup.com domain (and thus this will be broken).
    if request.cookies.has_key?(options.sso_cookie_name)
      response = Excon.get(options.userinfo_url,
        headers: { Authorization: request.cookies[options.sso_cookie_name].tr('"', '') })

      @auth_data = MultiJson.decode(response.body.to_s)
      super

    else
      fail!(:invalid_request)
    end

  rescue StandardError => e
    fail!(:invalid_response, e)
  end

end

auth_provider title: 'with SketchUp',
              message: 'Authenticating with SketchUp (make sure your pop up blocker is disabled).',
              frame_width: 725,
              frame_height: 600,
              authenticator: SketchupAuthenticator.new

register_css <<CSS
.btn-social.sketchup {
  background: #e72b2d;
  background-repeat: no-repeat;
  background-position: 30px 4px;
  background-size: 20px;
  padding-left: 30px;
  background-image: url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABYAAAAWCAYAAADEtGw7AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyJpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYwIDYxLjEzNDc3NywgMjAxMC8wMi8xMi0xNzozMjowMCAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENTNSBNYWNpbnRvc2giIHhtcE1NOkluc3RhbmNlSUQ9InhtcC5paWQ6OEJDQThGRTVGMUFBMTFFNEJCMkVBRTAzQzlCQjE3NDAiIHhtcE1NOkRvY3VtZW50SUQ9InhtcC5kaWQ6OEJDQThGRTZGMUFBMTFFNEJCMkVBRTAzQzlCQjE3NDAiPiA8eG1wTU06RGVyaXZlZEZyb20gc3RSZWY6aW5zdGFuY2VJRD0ieG1wLmlpZDo4QkNBOEZFM0YxQUExMUU0QkIyRUFFMDNDOUJCMTc0MCIgc3RSZWY6ZG9jdW1lbnRJRD0ieG1wLmRpZDo4QkNBOEZFNEYxQUExMUU0QkIyRUFFMDNDOUJCMTc0MCIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/Pj4YQzcAAANHSURBVHjarJTZb0xRHMd/524dHR1LO7VGdEGjtsRWJYJoKKUPXopQISFB/AMekIhXhBeJCE9EggexhGgi1oYuI1pEtUoXU11m6Vwzc+ee43trbjuambSWX/LJOXPvme/9befHhBCUxBwgB+SDOWBefJ0FMuNnVoMnlMIYhDdjLQarQC6YPviWc+K6TkLXYyLY3yKCwQ/C569i7qxStXBuCU4cBadSCbfjT1NNr/cjGUYHhN6KQMAjQnqd6O/3CH/A4H4/sbFjgZN4RyfFvraRY2vZUceGkpPQeATWJxN+Z7Z3aPrFS3kky8RUhUjRSIIIc2XIzOUqgOhyOdvtJkk+JwJ+PfLkGRl1HtKKi1an7618zNLSIvFUtSYKn8V6xKh+dUiYJpeyMotYRkYehHOZ0zmVJGkoMz7fTaRiG+/poeizF2S2QifdSek7K+qVgjkLcaQM3LGFK7FeplEa0nPNqKndHn1dS3DA+k1MlrUxOyreSO4sy+sT4DjipvcjqnFuoICdiGAa0lIh5+byNKezWpo8qUQaP2EBaWomY8wOTbU9ttrnGwmhEBckotFehNwg+nwN3O9rFIHgO7Orq545HN2OTRuvQHz3CG7sA5csj3tAtzBikyP37ufz3r5PEEOIIBwhNs6FYqqkzMoj3tdXKWtaIanq4hSiBmizNkr8QR3T1FIyzZlop09yzsx0qWB2MTpiEdrwMoVC3dzrpejTIElu9xKteIWHjXEsSCLcBdoThT2gVFu35rxatNwrT8peidYbeGe2fM4I37l37Ff21AL0ukOEQl9SCFuinb+qjCsNdokUxsPh70Zz81UeDLaIke1GXG9QeKn4P3bGFrZbpBEEByIwYjFc4dZYU9PVyIOHW8zWL9dp9PbV3tg5DoEqUG7U1ByOPn95wRpAJmaC0tRc7Tx4YGt84o1kbfZGSnh4a6CxXa4i6zZJEyeytHVrVyjzC8vFjx++UXrcNnRF4zkB2QPF0vWw0dR8Hev3v8hxzvDi2dz9h8L1AG148Wy7TX9mAXAD7AfWdIsmjs3EgzMSZ2oK88RH433w3LpDycfg76mwqBoWYi+4BvaAKUnOJ0VJ8i3Lm2XgNLgLXlrf/8MU0U8BBgDMytRJFjlrlgAAAABJRU5ErkJggg==);

}

CSS
