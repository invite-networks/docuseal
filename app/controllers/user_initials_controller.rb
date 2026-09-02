# frozen_string_literal: true

class UserInitialsController < ApplicationController
  before_action :load_user_config
  authorize_resource :user_config

  def edit; end

  def update
    attachment = UserConfigs::CreateSignatureAttachment.call(
      user: current_user,
      name: 'initials',
      file: params[:file],
      text: params[:text]
    )

    if @user_config.update(value: attachment.uuid)
      redirect_to settings_profile_index_path, notice: I18n.t('initials_has_been_saved')
    else
      redirect_to settings_profile_index_path, notice: I18n.t('unable_to_save_initials')
    end
  rescue UserConfigs::CreateSignatureAttachment::InvalidInput
    redirect_to settings_profile_index_path, notice: I18n.t('unable_to_save_initials')
  end

  def destroy
    @user_config.destroy

    redirect_to settings_profile_index_path, notice: I18n.t('initials_has_been_removed')
  end

  private

  def load_user_config
    @user_config =
      UserConfig.find_or_initialize_by(user: current_user, key: UserConfig::INITIALS_KEY)
  end
end
