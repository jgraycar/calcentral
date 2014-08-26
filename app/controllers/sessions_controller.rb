class SessionsController < ApplicationController
  include ActiveRecordHelper, ClassLogger

  skip_before_filter :check_reauthentication, :only => [:lookup, :destroy]

  def lookup
    auth = request.env["omniauth.auth"]
    auth_uid = auth['uid']
    if params[:renew] == 'true'
      # If we're reauthenticating due to view-as, then the CAS-provided UID should match
      # the session's "original_user_id".
      if session[:original_user_id]
        if session[:original_user_id] != auth_uid
          logger.warn "ACT-AS: Active user session for #{session[:original_user_id]} exists, but CAS is giving us a different UID: #{auth_uid}. Logging user out."
          logout
          return redirect_to Settings.cas_logout_url
        else
          create_reauth_cookie
        end
      elsif session[:user_id] != auth_uid
        # If we're reauthenticating for any other reason, then the CAS-provided UID should
        # match the session "user_id" from the previous authentication.
        logger.warn "REAUTHENTICATION: Active user session for #{session[:user_id]} exists, but CAS is giving us a different UID: #{auth_uid}. Starting new session."
        reset_session
      else
        create_reauth_cookie
      end
    else
      if session[:lti_authenticated_only] && session[:user_id] != auth_uid
        logger.warn "LTI user session for #{session[:user_id]} exists, but CAS is giving us a different UID: #{auth_uid}. Logging user out."
        logout
        return redirect_to Settings.cas_logout_url
      end
      # On normal first-time authentication, start with a clean session. This will have the side-effect
      # of clearing the LTI-authenticated-only flag if the user happened to visit bCourses first.
      reset_session
    end
    continue_login_success auth_uid
  end

  def create_reauth_cookie
    cookies[:reauthenticated] = {:value => true, :expires => 8.hours.from_now}
  end

  def reauth_admin
    redirect_to url_for_path("/auth/cas?renew=true&url=/ccadmin")
  end

  def basic_lookup
    uid = authenticate_with_http_basic do |uid, password|
      uid if password == Settings.developer_auth.password
    end

    if uid
      continue_login_success uid
    else
      failure
    end
  end

  def destroy
    logout
    render :json => {
      :redirectUrl => "#{Settings.cas_logout_url}?url=#{CGI.escape(request.protocol + request.host_with_port)}"
    }.to_json
  end

  def failure
    params ||= {}
    params[:message] ||= ''
    redirect_to root_path, :status => 401, :alert => "Authentication error: #{params[:message].humanize}"
  end

  private

  def smart_success_path
    # the :url parameter is returned by the CAS auth server
    (params[:url].present?) ? params[:url] : url_for_path('/dashboard')
  end

  def continue_login_success(uid)
    # Force a new CSRF token to be generated on login.
    # http://homakov.blogspot.com.es/2013/06/cookie-forcing-protection-made-easy.html
    session.try(:delete, :_csrf_token)
    if (Integer(uid, 10) rescue nil).nil?
      logger.warn "FAILED login with CAS UID: #{uid}"
      redirect_to url_for_path('/uid_error')
    else
      # Unless we're re-authenticating after view-as, initialize the session.
      session[:user_id] = uid unless session[:original_user_id]
      redirect_to smart_success_path, :notice => "Signed in!"
    end
  end

  def logout
    begin
      delete_reauth_cookie
      reset_session
    ensure
      ActiveRecord::Base.clear_active_connections!
    end
  end

end
