# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

Rspec.shared_examples 'User::hasTwoFactor' do
  subject(:user) { create(:user) }

  describe 'Instance methods:' do
    describe '#two_factor_configured?' do
      before do
        Setting.set('two_factor_authentication_method_authenticator_app', true)
      end

      context 'with no two factor configured' do
        it { is_expected.not_to be_two_factor_configured }
      end

      context 'with two factor configured' do
        before do
          Setting.set('two_factor_authentication_method_authenticator_app', true)
          create(:user_two_factor_preference, :authenticator_app, user:)
          user.reload
        end

        it { is_expected.to be_two_factor_configured }
      end
    end

    describe '#two_factor_destroy_all_authentication_methods' do
      let(:authenticator_app_preference) { create(:user_two_factor_preference, :authenticator_app, user:) }
      let(:security_keys_preference) { create(:user_two_factor_preference, :security_keys, user:) }

      before do
        Setting.set('two_factor_authentication_method_authenticator_app', true)
        authenticator_app_preference
      end

      it 'destroys both enabled and disabled methods' do
        security_keys_preference

        expect { user.two_factor_destroy_all_authentication_methods }
          .to change { user.two_factor_preferences.exists? }
          .to false
      end

      it 'destroys created authentication method' do
        expect { user.two_factor_destroy_all_authentication_methods }
          .to change { user.two_factor_preferences.exists? }
          .to false
      end
    end
  end
end
