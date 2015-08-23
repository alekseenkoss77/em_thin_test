class User
  attr_accessor :db

  def initialize(opt = {})
    @db = opt[:connection]
  end

  [:ip, :cookie].each do |method|
    # Dynamic finders. Find user from Redis DB
    # by ip address and cookie code.
    define_method("find_by_#{method}") do |id, proc|
      @db.get("em_users_#{method}:#{id}").callback(&proc)
    end

    define_method("identify_by_#{method}") do |id, host, _response|
      # find user by cookies or ip address
      # result is a String with format <server_address>|<switched>
      # <server_address> is Node ip address
      # <switched> is a special flag. It contains next values:
      # 0 - user has never been switched to other Nodes
      # 1 - user has been switched to other Node

      finder = proc do |result|
        if result.nil?
          @db.set("em_users_#{method}:#{id}", "#{host}|0").callback do
            p "[WRITED] em_users_#{method}:#{id} -> #{host}"
          end
          @db.incr("em_users_total_#{method}") do |res|
            p "[INCR] users total by #{method}. Current count: #{res}"
          end
        else
          server_addr, switched = result.split('|')
          # Check the first error switching.
          # if first user Node address isn't eql address from
          # current request and if user has never been switched before,
          # then increment statistic counter by method (ip or cookie)
          if (server_addr != host) && (switched == '0')
            @db.incr("em_switched_total_#{method}").callback do
              p "[INCR] switched statistic by #{method}"
            end
            # update user flag
            @db.set("em_users_#{method}:#{id}", "#{server_addr}|1")
          end
        end
      end

      send("find_by_#{method}", id, finder)
    end
  end
end
