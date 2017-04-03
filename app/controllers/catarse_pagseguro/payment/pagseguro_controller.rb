#encoding: utf-8
require "pagseguro-oficial"

module CatarsePagseguro::Payment
  class PagseguroController < ApplicationController
    skip_before_filter :verify_authenticity_token, :only => [:notifications, :success]
    skip_before_filter :detect_locale, :only => [:notifications, :success]
    skip_before_filter :set_locale, :only => [:notifications, :success]
    skip_before_filter :force_http

    layout :false

    def review
    end

    def ipn
      return unless request.post?

      notification_code = params[:notificationCode]
      notification = PagSeguro::Notification.new(::Configuration[:pagseguro_email], ::Configuration[:pagseguro_token], notification_code)

      backer = Backer.find_by_key notification.id
      backer.confirm! if notification.approved?

      backer.update_attributes({
        payment_service_fee: notification.fee_amount.to_f
      })

      if backer.payment_id != notification.transaction_id
        backer.update_attributes payment_id: notification.transaction_id
      end

      return render status: 200, nothing: true
    rescue Exception => e
      return render status: 500, text: e.inspect
    end


    def pay
      order = current_user.contributions.find params[:id]

      payment = PagSeguro::PaymentRequest.new

      payment.reference = order.id
      payment.redirect_url = main_app.project_url(order.project.id)
      payment.notification_url = payment_ipn_pagseguro_url

      payment.items << {
        id: order.id,
        description: "Apoio para o projeto #{order.project.name}",
        amount: order.value.to_f
      }

      puts payment.to_json

      response = payment.register
      
      render :partial => 'pay', locals: { code: response.code, order: order }
    end

    def success
      backer = current_user.contributions.find params[:id]
      begin
        backer.update_attributes payment_id: params[:id_pagseguro]
        redirect_to main_app.project_path(project_id: backer.project.id, id: backer.id)
      rescue Exception => e
        ::Airbrake.notify({ :error_class => "Paypal Error", :error_message => "Paypal Error: #{e.message}", :parameters => params}) rescue nil
        Rails.logger.info "-----> #{e.inspect}"
        pagseguro_flash_error
        return redirect_to main_app.new_project_backer_path(backer.project)
      end
    end

    def cancel
      backer = current_user.contributions.find params[:id]
      flash[:failure] = 'Pagamento cancelado'
      redirect_to main_app.new_project_backer_path(backer.project)
    end

  private

    def pagseguro_flash_error
      flash[:failure] = "Ops parece que aconteceu um erro ao realizar o seu apoio."
    end

    def pagseguro_flash_success
      flash[:success] = 'Apoio realizado com sucesso!'
    end

    
  end
end
