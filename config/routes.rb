CatarsePagseguro::Engine.routes.draw do
  namespace :payment do

    get '/pagseguro/:id/review' => 'pagseguro#review', :as => 'review_pagseguro'
    post '/pagseguro/notifications' => 'pagseguro#ipn',  :as => 'ipn_pagseguro'

    match '/pagseguro/:id/pay' => 'pagseguro#pay', via: [:get, :post],            :as => 'pay_pagseguro'

    match '/pagseguro/:id/success'  => 'pagseguro#success', via: [:get, :post],        :as => 'success_pagseguro'

    match '/pagseguro/:id/cancel' => 'pagseguro#cancel', via: [:get, :post],         :as => 'cancel_pagseguro'
  end
end

