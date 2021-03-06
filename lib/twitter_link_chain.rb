class TwitterLinkChain
  attr_accessor :parent_chain
  attr_reader :traveled_path, :visited_tweets, :tweet_queue

  CLIENT_ONE = Twitter::REST::Client.new do |config|
    config.consumer_key        = ENV["CONSUMER_KEY_1"]
    config.consumer_secret     = ENV["CONSUMER_SECRET_1"]
    config.access_token        = ENV["ACCESS_TOKEN_1"]
    config.access_token_secret = ENV["ACCESS_SECRET_1"]
  end

  CLIENT_TWO = Twitter::REST::Client.new do |config|
    config.consumer_key        = ENV["CONSUMER_KEY_2"]
    config.consumer_secret     = ENV["CONSUMER_SECRET_2"]
    config.access_token        = ENV["ACCESS_TOKEN_2"]
    config.access_token_secret = ENV["ACCESS_SECRET_2"]
  end

  TLC_STORE = YAML::Store.new "twitter_link_chain.store"

  def initialize(starting_tweet)
    stored = nil
    TLC_STORE.transaction do
      stored = TLC_STORE["stored"]
    end

    if stored == nil
      @starting_tweet = starting_tweet
      @traveled_path = [[nil,starting_tweet]]
      @visited_tweets = [starting_tweet]
      @tweet_queue = [starting_tweet]
    else
      TLC_STORE.transaction do
        @starting_tweet = TLC_STORE["current_tweet"]
        @traveled_path = TLC_STORE["traveled_path"]
        @visited_tweets = TLC_STORE["visited_tweets"]
        @tweet_queue = TLC_STORE["tweet_queue"]
      end
    end
  end

  def self.get_first_tweet_hash(starting_status_url)
    id = starting_status_url[/(\d)+$/].to_i
    link = true
    while link
      begin
        tweet = CLIENT_ONE.status(id)
        puts "#{tweet.user.screen_name}: #{id}"
        if tweet.urls
          id = tweet.urls.first.expanded_url.to_s[/(\d)+$/].to_i
        else
          link = false
        end
      rescue
        link = false
      end
    end

    {
      :username => tweet.user.screen_name,
      :id => tweet.id,
      :created_at => tweet.created_at,
      :retweet => tweet.retweet?,
      :retweet_count => tweet.retweet_count,
      :location => nil
    }

  end

  def visited?(tweet)
    visited_tweets.include?(tweet)
  end

  def add_to_path(parent, child)
    self.traveled_path << [parent, child]
  end

  def add_to_arrays(tweet)
    self.visited_tweets << tweet
    self.tweet_queue << tweet
  end

  def map_graph
    while !tweet_queue.empty?
      tweet = tweet_queue.shift
      TLC_STORE.transaction do
        TLC_STORE["stored"] = true
        TLC_STORE["current_tweet"] = tweet
        TLC_STORE["traveled_path"] = traveled_path
        TLC_STORE["visited_tweets"] = visited_tweets
        TLC_STORE["tweet_queue"] = tweet_queue
      end

      tweet.get_neighbors.each do |neighbor|
        if !visited?(neighbor)
          add_to_path(tweet, neighbor)
          add_to_arrays(neighbor)
        end
      end
    end
  end

  def display_graph(traveled_path)
    digraph do
      traveled_path.each do |pair|
        start = pair[0] == nil

        if start
          edge "#{pair[1].username}: #{pair[1].created_at.strftime("%a %b %e - %k:%M")}", "Start"
        else
          edge "#{pair[1].username}: #{pair[1].created_at.strftime("%a %b %e - %k:%M")}", "#{pair[0].username}: #{pair[0].created_at.strftime("%a %b %e - %k:%M")}"
        end
      end

      save "twitter_link_chain", "png"
    end
  end

end