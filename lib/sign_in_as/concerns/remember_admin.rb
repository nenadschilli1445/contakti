require 'devise/strategies/base'

module SignInAs
  module Concerns
    module RememberAdmin
      extend ActiveSupport::Concern


      def remember_admin_id
        request.env['rack.session']['devise.remember_admin_user_id']
      end

      def remember_admin_id=(id)
        request.env['rack.session']['devise.remember_admin_user_id'] = id
      end

      def remember_admin_id?
        request.env['rack.session'] && request.env['rack.session']['devise.remember_admin_user_id'].present?
      end

      def clear_remembered_admin_id
        request.env['rack.session']['devise.remember_admin_user_id'] = nil
      end
    end
  end
end