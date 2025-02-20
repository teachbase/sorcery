module Sorcery
  module Controller
    module Submodules
      # The Remember Me submodule takes care of setting the user's cookie so that he will
      # be automatically logged in to the site on every visit,
      # until the cookie expires.
      # See Sorcery::Model::Submodules::RememberMe for configuration options.
      module RememberMe
        def self.included(base)
          base.send(:include, InstanceMethods)
          Config.module_eval do
            class << self
              attr_accessor :remember_me_httponly, :remember_me_secure
              def merge_remember_me_defaults!
                @defaults.merge!(:@remember_me_httponly => true, :@remember_me_secure => false)
              end
            end
            merge_remember_me_defaults!
          end

          Config.login_sources << :login_from_cookie
          Config.before_logout << :forget_me!
        end

        module InstanceMethods
          # This method sets the cookie and calls the user to save the token and the expiration to db.
          def remember_me!
            current_user.remember_me!
            set_remember_me_cookie!(current_user)
          end

          # Clears the cookie, and depending on the value of remember_me_token_persist_globally, may clear the token value.
          def forget_me!
            current_user.forget_me!
            cookies.delete(:remember_me_token, domain: Config.cookie_domain)
          end

          # Clears the cookie, and clears the token value.
          def force_forget_me!
            current_user.force_forget_me!
            cookies.delete(:remember_me_token, domain: Config.cookie_domain)
          end

          # Override.
          # logins a user instance, and optionally remembers him.
          def auto_login(user, should_remember = false)
            session[:user_id] = user.id.to_s
            @current_user = user
            remember_me! if should_remember
          end

          protected

          # Checks the cookie for a remember me token, tried to find a user with that token
          # and logs the user in if found.
          # Runs as a login source. See 'current_user' method for how it is used.
          def login_from_cookie
            user = cookies.signed[:remember_me_token] && user_class.sorcery_adapter.find_by_remember_me_token(cookies.signed[:remember_me_token]) if defined? cookies
            if user && user.has_remember_me_token?
              set_remember_me_cookie!(user)
              session[:user_id] = user.id.to_s
              after_remember_me!(user)
              @current_user = user
            else
              @current_user = false
            end
          end

          def set_remember_me_cookie!(user)
            cookies.signed[:remember_me_token] = {
              value: user.send(user.sorcery_config.remember_me_token_attribute_name),
              expires: user.send(user.sorcery_config.remember_me_token_expires_at_attribute_name),
              httponly: Config.remember_me_httponly,
              domain: Config.cookie_domain,
              secure: Config.remember_me_secure
            }
          end
        end
      end
    end
  end
end
