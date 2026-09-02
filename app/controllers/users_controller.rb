# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :authorize_user_administration

  load_and_authorize_resource :user, only: %i[index edit update destroy]

  def index
    @users =
      if params[:status] == 'archived'
        @users.archived.where.not(role: 'integration')
      elsif params[:status] == 'integration'
        @users.active.where(role: 'integration')
      else
        @users.active.where.not(role: 'integration')
      end

    @users = @users.preload(account: :account_accesses).where(account: current_account).order(id: :desc)

    respond_to do |format|
      format.html do
        @pagy, @users = pagy(@users)
      end

      if current_ability.can?(:manage, current_account)
        format.csv do
          send_data Users.generate_csv(@users), filename: "users-#{Time.current.iso8601}.csv", type: 'text/csv'
        end
      end
    end
  end

  def edit; end

  def update
    return redirect_to settings_users_path, notice: I18n.t('unable_to_update_user') if Docuseal.demo?

    attrs = user_params.compact_blank
    attrs = attrs.merge(user_params.slice(:archived_at)) if current_ability.can?(:create, @user)

    if params.dig(:user, :account_id).present?
      account = Account.accessible_by(current_ability).find(params.dig(:user, :account_id))

      authorize!(:manage, account)

      @user.account = account

      authorize!(:create, @user)
    end

    if @user.update(attrs.except(:email))
      if @user.try(:pending_reconfirmation?) && @user.previous_changes.key?(:unconfirmed_email)
        SendConfirmationInstructionsJob.perform_async('user_id' => @user.id)

        redirect_back fallback_location: settings_users_path,
                      notice: I18n.t('a_confirmation_email_has_been_sent_to_the_new_email_address')
      else
        redirect_back fallback_location: settings_users_path, notice: I18n.t('user_has_been_updated')
      end
    else
      render turbo_stream: turbo_stream.replace(:modal, template: 'users/edit'), status: :unprocessable_content
    end
  end

  def destroy
    if Docuseal.demo? || @user.id == current_user.id
      return redirect_to settings_users_path, notice: I18n.t('unable_to_remove_user')
    end

    @user.update!(archived_at: Time.current)

    redirect_back fallback_location: settings_users_path, notice: I18n.t('user_has_been_removed')
  end

  private

  def authorize_user_administration
    authorize!(:manage, :users)
  end

  def user_params
    if params.key?(:user)
      params.require(:user).permit(:first_name, :last_name, :archived_at)
    else
      {}
    end
  end
end
