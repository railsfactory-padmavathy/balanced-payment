require 'balanced'
class BalancedController < ApplicationController
  before_filter :authenticate_user,:only => [:enter,:merchant]
  before_filter :marketplace_creation, :except => [:enter_new,:confirm,:index,:success,:destroy_cart,:checkout,:success]
  
  def index
    puts "reached controller for index"
   
  end

  def confirm
  
  end

  def enter_new
  end
    
  def payment
    if User.authenticate(params[:email], params[:password])
      @market = marketplace_creation
      marketplace = @market
      buyer = Balanced::Account.find_by_email(params[:email])
      card =buyer.cards[0].uri
      order_item = Order.new({:user_id=> session[:user_id],:amount=>session[:amount]})
      if !session[:images].nil?
        session[:images].split(",").each do |pic|
          image=Image.find_by_id(pic)
          amount= image.price
          order_item.amount = amount
          owner=image.user
          bank_process(owner,amount,image,buyer,card,marketplace,order_item)
        end
      end
      if !session[:videos].nil?
        session[:videos].split(",").each do |pic|
          video=Video.find_by_id(pic)
          amount= video.price
          order_item.amount = amount
          owner=video.user
          bank_process(owner,amount,video,buyer,card,marketplace,order_item)
        end
      end
      if !session[:audio].nil?
        session[:audio].split(",").each do |pic|
          audio=Audio.find_by_id(pic)
          amount= audio.price
          order_item.amount = amount
          owner=audio.user
          bank_process(owner,amount,audio,buyer,card,marketplace,order_item)
        end
      end
      if !session[:data_files].nil?
        session[:data_files].split(",").each do |pic|
          data_file=DataFile.find_by_id(pic)
          amount= data_file.price
          order_item.amount = amount
          owner=data_file.user
          bank_process(owner,amount,data_file,buyer,card,marketplace,order_item)
        end
      end
      Notifier.got_a_payment.deliver
      destroy_cart
      flash[:notice] = "Thank you for purchasing."
                
      respond_to do |format|
        format.html { redirect_to orders_user_path(session[:user_id]) }
        format.json  {  render :json => {:success=>""}}
      end
    else
      redirect_to balanced_confirm_path
      flash[:notice]="check the email/password"
    end
            
  end
    
    
  def enter
    @response=@response1=@response2=@response3=true
    if params[:format] == "json"
      if params[:amount].present? && params[:item_id].present? && params[:item_type].present? && !params[:amount].nil? && !params[:item_id].nil? && !params[:item_type].nil?
        if Order.joins(:order_items).where(['orderable_id = ? AND orderable_type = ? AND user_id=? ',params[:item_id],params[:item_type],session[:user_id]]).empty?
          flag = 0
          session[:amount] = params[:amount]
          case params[:item_type]
          when "image" , "Image" , "IMAGE"
            p session[:images] = ["#{params[:item_id]}"]
          when "audio" , "Audio" , "AUDIO"
            session[:audio] = ["#{params[:item_id]}"]
          when "video" , "Video" , "VIDEO"
            session[:videos] = ["#{params[:item_id]}"]
          when "file" , "File" , "FILE"
            session[:date_files] = ["#{params[:item_id]}"]
          end
        else
          flag = 1
          respond_to do |format|
            format.json {render :json=>{:error=>"Already you have purchased this item"}}
          end
        end
      end
 
    end
    
    #Need to check if buyer already exists

    #getting card details from form and then creating a new card
    #using dummy card details (5105105105105100,12,2015)
    if flag!=1
      if params['card_number'] != nil && params['expiration_month'] != nil && params['expiration_year'] != nil && params['security_code'] != nil
        begin
          card = Balanced::Card.new(
            :card_number => params['card_number'],
            :expiration_month => params['expiration_month'],
            :expiration_year => params['expiration_year'],
            :security_code => params['security_code'] #for now not using it as our dummy card doesnt have security code on it
          ).save
        rescue Balanced::Error => error
          puts error.message.inspect
          respond_to do |format|
            format.html {redirect_to '/balanced/enter_new'}
            format.json {render :json=>{:error=>"card not valid"}}
          end
          flash[:message] = "Card Details are not valid"
        end
            
            
        if card
          puts "Our card uri: #{card.uri}"
          puts "successfully saved card detials"
            
          #Creating a new buyer (Need to get email id of buyer from database in actual application)
          @market = marketplace_creation
          marketplace = @market
          params[:format] !="json" ? buyer = Balanced::Account.find_by_email(current_user.email) :  buyer = Balanced::Account.find_by_email((User.find_by_id(session[:user_id])).email)
          if !buyer.present?
            buyer = marketplace.create_buyer(
              :email_address => current_user.email,
              :card_uri => card.uri
            )
          else
            buyer.add_card(card.uri)
          end
          puts "our buyer account: #{buyer.uri}"
          @amount = 0
                  
          order_item = Order.new({:user_id=> session[:user_id],:amount =>session[:amount]})
          if !session[:images].nil?
            session[:images].split(",").each do |pic|
              image=Image.find_by_id(pic)
              amount= image.price
              owner=image.user
              @response= bank_process(owner,amount,image,buyer,card.uri,marketplace,order_item)
            end
          end
          if !session[:videos].nil?
            session[:videos].split(",").each do |pic|
              video=Video.find_by_id(pic)
              amount= video.price
              owner=video.user
              @response1= bank_process(owner,amount,video,buyer,card.uri,marketplace,order_item)
            end
          end
          if !session[:audio].nil?
            session[:audio].split(",").each do |pic|
              audio=Audio.find_by_id(pic)
              amount= audio.price
              owner=audio.user
              @response2= bank_process(owner,amount,audio,buyer,card.uri,marketplace,order_item)
            end
          end
          if !session[:data_files].nil?
            session[:data_files].split(",").each do |pic|
              data_file=DataFile.find_by_id(pic)
              amount= data_file.price
              owner=data_file.user
              @response3= bank_process(owner,amount,data_file,buyer,card.uri,marketplace,order_item)
            end
          end
                
          if @response !=false && @response1 !=false && @response2 !=false && @response3 !=false
            Notifier.got_a_payment.deliver
            destroy_cart
            flash[:notice] = "Thank you for purchasing."
                
            respond_to do |format|
              format.html { redirect_to orders_user_path(current_user) }
              format.json  {  render :json => {:order_id=>Order.find_all_by_user_id(current_user.id).last.id,:message=>"transaction completed successfully"}}
            end
          else
		        respond_to do |format|  
              format.html {redirect_to '/balanced/enter_new'}
              format.json {render :json=>{:error=>"payment was not made successful, Please check your item"}}
		        end
            flash[:message] = "Transaction Failed, Please check your item"
          end
        end
      end
    end
  end

  def bank_process(owner,amount,item,buyer,card,marketplace,order)   
    begin
      merchant = Balanced::BankAccount.find("/v1/bank_accounts/#{owner.bank_account_uri}")
      #~ puts "our merchant account: #{merchant.bank_accounts_uri}"
      another_debit = buyer.debit(
        :amount => amount.to_i*100,
        :appears_on_statement_as => "MARKETPLACE.COM",:card_uri=>card
      )
      credit_amount = ((amount.to_i*100)*70)/100
      credit = merchant.credit(
        :amount => credit_amount,
        :description => "Buyer purchased something on MARKETPLACE.COM",:bank_account_uri=>merchant.uri
      )
      puts "marketplace charges 30%, so it earned $15.9"
                        
      credit_amt = ((amount.to_i*100)*30)/100
      mp_credit = marketplace.owner_account.credit(
        :amount => credit_amt,
        :description => "Our commission from MARKETPLACE.COM"
      )
    rescue Balanced::Error => error
      puts error.message.inspect
      return false
    else
      Notifier.got_a_download(item,current_user).deliver
      Notifier.got_a_purchase(item,current_user).deliver
      order.order_items  << OrderItem.new(:orderable => item ,:price => amount, :payment_sent_to_seller => 1)
      order.save!
    end
    
  end
  
  
  def buyer   
    if !params['card_number'].nil? && !params['expiration_month'].nil? && !params['expiration_year'].nil?
      begin
        p card = Balanced::Card.new(
          :card_number => params['card_number'],
          :expiration_month => params['expiration_month'],
          :expiration_year => params['expiration_year'],
          :security_code => params['security_code'] #for now not using it as our dummy card doesnt have security code on it
        ).save
      rescue Balanced::Error => error
        puts error.message.inspect
        redirect_to edit_user_path(session[:user_id])
        flash[:success] = "Card Details are not valid"
      end
      if card
        @market = marketplace_creation
        marketplace = @market
        buyer = Balanced::Account.find_by_email(current_user.email)
        #~ buyer.add_card(card.uri)
        if !buyer.present?
          buyer = marketplace.create_buyer(
            :email_address => current_user.email,
            :card_uri => card.uri
          )
          puts "our buyer account: #{buyer.uri}"
        end
        @user=User.find(session[:user_id])
        @user.update_attribute("credit_active",true)
        redirect_to edit_user_path(session[:user_id])
        flash[:success] = "Thanks for updating credit details"
      end
    end
  end
 def merchant
    after_redirection = "#{root_url}balanced/success"
    current_user = User.find(session[:user_id])
    begin    
         existing=Balanced::Account.find_by_email(current_user.email)  
         @market = marketplace_creation
        marketplace = @market  
          bank_account = marketplace.create_bank_account(
          :account_number => params[:account_number],
          :bank_code => params[:bankcode],
          :name => current_user.full_name
        )        
      if existing.nil?              
        session[:bank_account_uri] = bank_account.uri
        merchant = marketplace.create_merchant(
          :email_address => current_user.email,
          :merchant => {
            :type => params[:account_type],
            :name => current_user.full_name,
            :street_address => current_user.street,
            :postal_code => current_user.zipcode,
            :dob => current_user.date_of_birth,
            :phone_number => params[:phone_number],
          },
          :bank_account_uri => bank_account.uri,
          :name => current_user.full_name
        )
      else
        session[:bank_account_uri] = bank_account.uri
        existing.promote_to_merchant(
          {
            :type => params[:account_type],
            :name => current_user.full_name,
            :street_address => current_user.street,
            :postal_code => current_user.zipcode,
            :dob => current_user.date_of_birth,
            :phone_number => params[:phone_number],
          }
        )
      end    
      respond_to do |format|
        format.html {  
      @user=User.find(session[:user_id])
      @user.update_attributes(:bank_account_uri=>session[:bank_account_uri],:bank_active=>true)
      session[:bank_account_uri] = nil
       redirect_to '/public/bank_info?bank=success'
      flash[:success] = "Bank information successfully updated"  }
        format.json {render :json => {:success => "Bank information successfully updated"}}
      end
    rescue Balanced::MoreInformationRequired => ex
       redirect_to ex.redirect_uri + '?redirect_uri=' + after_redirection
       #~ flash[:success] = "Bank info saved" 
    rescue Balanced::Error => error
      puts error.message.inspect
      respond_to do |format|
        format.html { redirect_to edit_user_path(session[:user_id])
          flash[:error] = "merchant account not created, please check your bank info"}
        format.json {render :json => {:error => "merchant account not created, please check your bank info"}}
      end
    end  
  end
  
  def success
    @user=User.find(session[:user_id])
    unless params["merchant_uri"].nil?     
     @market = marketplace_creation
      marketplace = @market
      existing=Balanced::Account.find_by_email(current_user.email)
      if !existing.nil?
      merchant = existing.promote_to_merchant(:merchant_uri=>params["merchant_uri"])    
      else
       merchant = marketplace.create_merchant(
        :email_address => params["email_address"],
        :merchant =>params["merchant_uri"],
        :bank_account => session[:bank_account_uri],
        :name => current_user.full_name
        )   
      end  
      @user.update_attributes(:bank_account_uri=>session[:bank_account_uri],:bank_active=>true)
      session[:bank_account_uri] = nil
      redirect_to '/public/bank_info?bank=success'
      flash[:success] = "Bank information successfully updated" 
    else
      redirect_to edit_user_path(session[:user_id])      
    end
  end
  
  
  def checkout
    session[:amount]=params[:amount]
    if current_user.credit_active == true
      redirect_to balanced_confirm_path
    else
      redirect_to balanced_enter_new_path
    end
  end

  private
  
  def destroy_cart
    session[:images] = nil
    session[:audios] = nil
    session[:videos] = nil
    session[:data_files] = nil

  end
  
  
end 
