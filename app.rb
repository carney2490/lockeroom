require 'sinatra'
require 'rubygems'
require 'tilt/erb'
require 'bcrypt'
require 'pony'
require 'pg'
require 'mail'

load "./local_env.rb" if File.exists?("./local_env.rb")

db_params = {
   host: "lockerroom.ccar1za80ci4.us-west-2.rds.amazonaws.com:5432",
   port:'5432',
   dbname:'lockerroom',
   user:ENV['user'],
   password:ENV['password'],    
}

db = PG::Connection.new(db_params)

set :sessions, 
	key: ENV['sessionkey'],
	domain:  ENV['domain'],
	path: '/',
	expire_after: 3600,
	secret: ENV['sessionsecret']

get '/' do
    @title = 'LockerRoom'
    erb :index
end

get '/contact' do
    @title = 'Contact Us'
    erb :contact
end

get '/customer_account' do
    @title = 'Customer Account'
    erb :customer_account
end



get '/customer_order' do
    @title = 'Orders'
    erb :customer_order
end

get '/category_full' do
    @title = 'Categories'
    erb :category_full
end

get '/checkout1' do
    @title = 'Checkout Step1'
    erb :checkout1, :locals => {:cart => session[:cart]}
end

get '/checkout2' do
    @title = 'Checkout Step2'
    erb :checkout2, :locals => {:cart => session[:cart]}
end

get '/checkout3' do
    @title = 'Checkout Step3'
    erb :checkout3, :locals => {:cart => session[:cart]}
end

get '/checkout4' do
    @title = 'Checkout Step4'
    session[:cart] = []
    erb :checkout4, :locals => {:cart => session[:cart]}
end

get '/customer_register' do
    @title = 'Register'
    erb :customer_register, :locals => {:message => " ", :message1 => " "}
end

get '/product_details' do
    @title = 'Product Details'
    erb :product_details, :locals => {:product_info => " ", :size_price => " "}
end

post '/facebook' do
    @title = 'Facebook Login'    
    name= params[:name]
    email = params[:email]
    
    check_email = db.exec("SELECT * FROM users WHERE email = '#{email}'")
    
    if check_email.count > 0
        puts '#{check_email}'
    else
        facebook_log = db.exec ("INSERT INTO users (open_sso_data, name, email) VALUES ('facebook', '#{name}','#{email}' )" )
    end
    session[:user] = name
    session[:email] = email
    
    redirect '/'   
end

post '/google' do
    @title = 'Google Login'
    
    name = params[:gname]
    email = params[:gemail]
    
    check_email = db.exec("SELECT * FROM users WHERE email = '#{email}'")
    
    if check_email.count > 0
        puts '#{check_email}'
    else
        google_log = db.exec ("INSERT INTO users (open_sso_data, name, email) VALUES ('google', '#{name}','#{email}')" )
    end
    session[:user] = name
    session[:email] = email
    redirect '/'   
end
get '/faq' do
    @title = 'FAQ'
    erb :faq
end

get '/about' do
    title = 'About'
    erb :about
end

Mail.defaults do
  delivery_method :smtp, 
  address: "email-smtp.us-east-1.amazonaws.com", 
  port: 587,
  :user_name  => ENV['a3smtpuser'],
  :password   => ENV['a3smtppass'],
  :enable_ssl => true
end

post '/contact' do
  name = params[:firstname]
  lname= params[:lastname]
  email= params[:email]                  
  comments = params[:message]
  subject= params[:subject]
  email_body = erb(:email2,:layout=>false, :locals=>{:subject => subject,:firstname => name, :lastname => lname, :email => email, :message => comments})
  
  mail = Mail.new do
    from         ENV['from']
    to           email
    bcc          ENV['from']
    subject      subject
    
    html_part do
      content_type 'text/html'
      body         email_body
    end
  end

  mail.deliver!
    erb :success, :locals => {:message => "Thanks for contacting us."}
end

get '/order_now' do
    @title = 'Order Now'
    erb :order_now
end

post '/submit' do
    erb :submit1
end    
      
post '/customer_register' do
    fname = params[:fname]
    lname = params[:lname]
    address = params[:address]
    city = params[:city]
    state = params[:state]
    zipcode = params[:zipcode]
    email = params[:email]
    phone = params[:phone]
    password = params[:password]
    name = "#{fname} #{lname}"
    
    #This is for creating profile and preventing duplication
    check_email = db.exec("SELECT * FROM users WHERE email = '#{email}'")
    
    hash = BCrypt::Password.create(password, :cost => 11) 
    
    
        if check_email.num_tuples.zero? == false
            erb :customer_register, :locals => {:message => " ", :message1 => "That email already exists"}
        else
            db.exec ("INSERT INTO users (fname, lname, address, city, state, zipcode, email, phone, encrypted_password, name ) VALUES ('#{fname}', '#{lname}', '#{address}','#{city}', '#{state}', '#{zipcode}', '#{email}','#{phone}', '#{hash}', '#{name}')" )
            erb :success, :locals => {:message => "You have successfully registered.", :message1 => " "}
        end
end

post '/submit3' do
    # Standard Log In
    password = params[:password]
    email = params[:email]
    
    match_login = db.exec("SELECT encrypted_password, user_type, email FROM users WHERE email = '#{email}'")
    
        if match_login.num_tuples.zero? == true
            error = erb :login, :locals => {:message => "invalid email and password combination"}
            return error
        end
    
    password1 = match_login[0]['encrypted_password']
    comparePassword = BCrypt::Password.new(password1)
    user_type = match_login[0]['user_type']
	email =  match_login[0]['email']
    
      if match_login[0]['email'] == email &&  comparePassword == password

		 
		  session[:user_type] = user_type
          session[:email] = email  
          erb :index
      else
		  erb :customer_register, :locals => {:message => "invalid username and password combination"}
      end
    redirect '/' 
end

post '/login' do
    email = params[:email]
    password = params[:password]
    
    match_login = db.exec("SELECT encrypted_password,user_type,email,name,user_name FROM users WHERE email = '#{email}'")
    
        if match_login.num_tuples.zero? == true
            error = erb :login, :locals => {:message => "invalid email and password combination"}
            return error
        end
    
    password1 = match_login[0]['encrypted_password']
    comparePassword = BCrypt::Password.new(password1)
	
    user_email = match_login[0]['email']
    user_name = match_login[0]['name']
    user_type = match_login[0]['user_type']
    
      if match_login[0]['email'] == email && comparePassword == password
          session[:email] = user_email  
          session[:usertype] = user_type
          session[:user] = user_name
          puts "authenticated"
          erb :index
      else
		  erb :login, :locals => {:message => "invalid username and password combination"}
      end 
end
      
get '/logout' do
	session[:user] = nil
	session[:usertype] = nil
    session[:email] = nil
	redirect '/'
end

get '/school_order_form2' do
    @title = 'LockerRoom'
    erb :school_order_form2
end

post '/school_order_form2' do
    @title = 'LockerRoom'
    erb :product_details, :locals => {:product_info => product_info, :size_price => size_price}
end

post '/product_details' do
    url = params[ :url]
    
    size_price = db.exec("SELECT size, price FROM products2 WHERE product_url = '#{url}' ORDER BY size ASC  ")
    
    product_info = db.exec("SELECT product_name, product_description, order_information, product_url, personalization FROM products2 WHERE product_url = '#{url}' LIMIT 1")
    
    @title = 'Product Details'
    erb :product_details, :locals => {:product_info => product_info, :size_price => size_price}
end

post '/checkout2' do
    @title = 'Checkout Step2'
    erb :checkout2,:locals => {:cart => session[:cart]}
end

post '/checkout3' do
    @title = 'Checkout Step3'
    erb :checkout3,:locals => {:cart => session[:cart]}
end

post '/checkout4' do
    @title = 'Checkout Step4'
    erb :checkout4,:locals => {:cart => session[:cart]}
end

get '/admin_page' do
    @title = 'Admin Page'
    mailing_list = db.exec("SELECT email FROM mailing_list")
    mailing_list = mailing_list.values.join(", ")
   
    erb :admin_page,:locals =>{:mailing_list => mailing_list}
end
get '/edit_profile'do
    @title = 'Edit Profile'
    users = db.exec("SELECT * FROM users WHERE email='#{session[:email]}'")
    edit_profile = db.exec("SELECT fname,lname,address,city,state,zipcode,email,phone FROM users WHERE email = '#{session[:email]}' ")  
    current_profile= db.exec("SELECT * FROM users WHERE email='#{session[:email]}'")
    erb :edit_profile, :locals => {:edit_profile => edit_profile,:users =>users,:current_profile =>current_profile}
end

post '/edit_profile' do
   fname = params[:fname]
   lname = params[:lname]
   address = params[:address]
   city = params[:city]
   state = params[:state]
   zipcode = params[:zipcode]
   email = params[:email]
   phone = params[:phone]
    users = db.exec("SELECT * FROM users WHERE email='#{session[:email]}'")       
    update_profile = db.exec ("UPDATE users SET (fname,lname, address, city, state, zipcode, email, phone)  =  ('#{fname}','#{lname}', '#{address}','#{city}', '#{state}', '#{zipcode}', '#{email}', '#{phone}' ) WHERE email = '#{email}'" )
    redirect '/edit_profile'
end

get '/product_details' do
    @title = 'Product Details'
    erb :product_details
end

post '/product_details' do
    url = params[:url]
    
    size_price = db.exec("SELECT size, price FROM products2 WHERE product_url = '#{url}' ORDER BY size ASC  ")
    
    product_info = db.exec("SELECT product_name, product_description, order_information, product_url, personalization FROM products2 WHERE product_url = '#{url}' LIMIT 1")
    
    @title = 'Product Details'
    erb :product_details, :locals => {:product_info => product_info, :size_price => size_price}
end

def moneyToFloat(money)
    
    result = money.to_f
    return result
end

get '/shop_cart' do
    @title = 'Shopping Cart'
    session[:cart] ? cart = session[:cart] : cart = []
    erb :shop_cart, :locals => {:cart => session[:cart]}
end

post '/shop_cart' do
    @title = 'Shopping Cart'
    
    session[:cart] ||= []
    
    name = params[:productName]
    description = params[:productDescription]
    url = params[:productURL]
    size = params[:size]
    quantity = params[:quantity].to_i
    price = moneyToFloat(params[:price])
    personalization = params[:personalize]
    lastname = params[:lastname]
    number = params[:pnumber]
    total = quantity * price
    
    session[:cart].push({"name": name, "description": description, "url": url, "size": size, "quantity": quantity, "price": price, 
                         "total": total, "personalization": personalization, "lastname": lastname, "number": number})
    redirect '/shop_cart'
end

post '/update_cart' do
    index = params[:index].to_i
    quantity = params[:quantity].to_i
    price = session[:cart][index][:price]
    total = quantity * price
    session[:cart][index][:quantity] = quantity
    total = session[:cart][index][:total]
    redirect '/shop_cart'
end

post '/remove_from_cart' do
    index = params[:index].to_i
    session[:cart].delete_at(index)
    redirect '/shop_cart'
end
post '/checkout1' do
    @title = 'Checkout Step1'
    erb :checkout1, :locals => {:cart => session[:cart]}
end