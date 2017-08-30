#encoding: utf-8
require "pagseguro-oficial"

module CatarsePagseguro::Payment
  class PagseguroController < ApplicationController
    skip_before_filter :verify_authenticity_token, :only => [:notifications, :success]
    skip_before_filter :detect_locale, :only => [:notifications, :success]
    skip_before_filter :set_locale, :only => [:notifications, :success]
    skip_before_filter :force_http

    layout :false

    #variáveis para facilitar o mapeamento de códigos Pagseguro
    STATUS = ["no status", "pending", "in analysis", "paid", "available", "em disputa", "devolved","canceled"]

    PAYMENT_METHOD = ["no info", "CartaoDeCredito", "BoletoBancario", "DebitoBancario", "SaldoPagseguro", "", "","DepositoEmConta"]


    def review
    end

    def ipn
      transaction = PagSeguro::Transaction.find_by_notification_code(params[:notificationCode])

      if transaction.errors.empty?
        # Processa a notificação. A melhor maneira de se fazer isso é realizar
        # o processamento em background. Uma boa alternativa para isso é a
        # biblioteca Sidekiq.
        payment = Payment.find_by_key(transaction.code)
        if not transaction.nil?
          payment.state = STATUS[transaction.status.id.to_i]
        else
          payment.state = 0
        end
        
        payment.save
      end

      render nothing: true, status: 200
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

      response = payment.register

      render :partial => 'pay', locals: { code: response.code, order: order }
    end


    def success
      backer = current_user.contributions.find params[:id]

      if params.has_key?(:transactionCode)
        response = PagSeguro::Transaction.find_by_code(params[:transactionCode])

        begin

          payment = {
            contribution: backer,
            value: backer.value,
            payment_method: PAYMENT_METHOD[response.payment_method.type_id.to_i],
            state: STATUS[response.status.id.to_i],
            gateway: "pagseguro",
            gateway_id: response.reference,
            gateway_data: response.to_json,
            installments: response.installments,
            key: response.code,
            gateway_fee: (response.creditor_fees.intermediation_rate_amount.to_f + response.creditor_fees.intermediation_fee_amount.to_f)
          }

          p = Payment.new(payment)
          p.save

          pagseguro_flash_success
          redirect_to main_app.project_path(backer.project.id)
        rescue Exception => e
          ::Airbrake.notify({ :error_class => "PagSeguro Error", :error_message => "PagSeguro Error: #{e.message}", :parameters => params}) rescue nil
          Rails.logger.info "-----> #{e.inspect}"
          pagseguro_flash_error
          return redirect_to main_app.project_path(backer.project.id)
        end

      else # else do if params.has_key
        begin

          payment = {
            contribution: backer,
            value: backer.value,
            payment_method: "pagseguro",
            state: "pending",
            gateway: "pagseguro"
          }

          p = Payment.new(payment)
          p.save

          pagseguro_flash_success
          redirect_to main_app.project_path(backer.project.id)

        rescue Exception => e
          ::Airbrake.notify({ :error_class => "PagSeguro Error", :error_message => "PagSeguro Error: #{e.message}", :parameters => params}) rescue nil
          Rails.logger.info "-----> #{e.inspect}"
          pagseguro_flash_error
          return redirect_to main_app.project_path(backer.project.id)
        end

      end # if params.has_key
    end

    def cancel
      backer = current_user.contributions.find params[:id]
      flash[:failure] = 'Pagamento cancelado'
      redirect_to main_app.project_path(backer.project.id)
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
