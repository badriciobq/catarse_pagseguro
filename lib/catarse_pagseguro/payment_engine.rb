module CatarsePagseguro
  class PaymentEngine
    def name
      'pagseguro'
    end

    def review_path contribution
      CatarsePagseguro::Engine.routes.url_helpers.payment_review_pagseguro_path(contribution)
    end

    def locale
      'pt'
    end
  end
end

