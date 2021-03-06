########################################################################
# File::    utilities.rb
# (C)::     Loyalty New Zealand 2014
#
# Purpose:: Miscellaneous useful functions.
# ----------------------------------------------------------------------
#           22-Sep-2014 (ADH): Created.
########################################################################

require 'socket'

module Hoodoo

  # Useful tools, especially for those working without Rails components.
  #
  module Utilities

    # Validation regular expression for DateTime subset selection.
    #
    DATETIME_ISO8601_SUBSET_REGEXP = /(\d{4})-(\d{2})-(\d{2})T(\d{2})\:(\d{2})\:(\d{2})(\.\d+)?(Z|[+-](\d{2})\:(\d{2}))/

    # Validation regular expression for Date subset selection.
    #
    DATE_ISO8601_SUBSET_REGEXP = /(\d{4})-(\d{2})-(\d{2})/

    # Given a hash, returns the same hash with keys converted to symbols.
    # Works with nested hashes.
    #
    # +obj+:: Hash or Array of Hashes. Will recursively convert keys in Hashes
    #         to symbols. Hashes with values that are Arrays of Hashes will be
    #         dealt with properly. Does not modify other types (e.g. an Array
    #         of Strings would stay an Array of Strings).
    #
    # Returns a copy of your input object with keys converted to symbols.
    #
    def self.symbolize(obj)

      # http://stackoverflow.com/questions/800122/best-way-to-convert-strings-to-symbols-in-hash
      #
      return obj.inject({}){|memo,(k,v)| memo[k.to_s.to_sym] =  self.symbolize(v); memo} if obj.is_a?(::Hash)
      return obj.inject([]){|memo,v    | memo                << self.symbolize(v); memo} if obj.is_a?(::Array)
      return obj
    end

    # The keys-to-strings equivalent of ::symbolize.
    #
    # +obj+:: Hash or Array of Hashes. Will recursively convert keys in Hashes
    #         to strings. Hashes with values that are Arrays of Hashes will be
    #         dealt with properly. Does not modify other types (e.g. an Array
    #         of Symbols would stay an Array of Symbols).
    #
    # Returns a copy of your input object with keys converted to strings.
    #
    def self.stringify(obj)
      return obj.inject({}){|memo,(k,v)| memo[k.to_s] =  self.stringify(v); memo} if obj.is_a?(::Hash)
      return obj.inject([]){|memo,v    | memo         << self.stringify(v); memo} if obj.is_a?(::Array)
      return obj
    end

    # Thorough but slow deep duplication of any object (if it isn't
    # duplicable, e.g. FixNum, you just get the same thing back). Usually
    # used with Hashes or Arrays.
    #
    # +obj+:: Object to duplicate.
    #
    # Returns the duplicated object if duplicable, else returns the input
    # parameter.
    #
    def self.deep_dup( obj )
      duplicate = obj.dup rescue obj

      result = if duplicate.is_a?( Hash )
        duplicate.each { | k, v | duplicate[ k ] = deep_dup( v ) }
      elsif duplicate.is_a?( Array )
        duplicate.map { | entry | deep_dup( entry ) }
      else
        duplicate
      end

      return result
    end

    # Deep merge two hashes.
    #
    # Hash#merge/merge! only do a shallow merge. For example, without
    # a block, when starting with this hash:
    #
    #     { :one => { :two => { :three => 3 } } }
    #
    # ...and merging in this hash:
    #
    #     { :one => { :two => { :and_four => 4 } } }
    #
    # ...the possibly unexpected result is this:
    #
    #     { :one => { :two => { :and_four => 4 } } }
    #
    # Because the value for key ":one" in the original hash is simply
    # overwritten with the value from the merged-in hash.
    #
    # Deep merging takes a target hash, into which an "inbound" source
    # hash is merged and returns a new hash that is the deep merged
    # result. Taking the above example:
    #
    #     target_hash  = { :one => { :two => { :three => 3 } } }
    #     inbound_hash = { :one => { :two => { :and_four => 4 } } }
    #     Hoodoo::Utilities.deep_merge_into( target_hash, inbound_hash )
    #
    # ...yields:
    #
    #     { :one => { :two => { :three => 3, :and_four => 4 } } }
    #
    # For any same-named key with a non-hash value, the value in the
    # inbound hash will overwrite the value in the target hash.
    #
    # Parameters:
    #
    # +target_hash+::  The hash into which something will be merged.
    # +inbound_hash+:: The hash that will be merged into the target.
    #
    # Returns the merged result.
    #
    def self.deep_merge_into( target_hash, inbound_hash )

      # http://stackoverflow.com/questions/9381553/ruby-merge-nested-hash
      #
      merger = proc { | key, v1, v2 |
        v1.is_a?( Hash ) && v2.is_a?( Hash ) ? v1.merge( v2, &merger ) : v2.nil? ? v1 : v2
      }

      return target_hash.merge( inbound_hash, &merger )
    end

    # Deep diff two hashes.
    #
    # +hash1+:: "Left hand" hash for comparison.
    # +hash2+:: "Right hand" hash for comparison.
    #
    # The returned result is a Hash itself, potentially nested, with any
    # present key paths leading to an array describing the difference found
    # at that key path. If the two input hashes had values at the path, the
    # differing values are placed in the array ("left hand" value at index
    # 0, "right hand" at index 1). If one input hash has a key leading to
    # a value which the other omits, the array contains +nil+ for the
    # omitted entry.
    #
    # Example:
    #
    #     hash1 = { :foo => { :bar => 2 }, :baz => true, :boo => false }
    #     hash2 = { :foo => { :bar => 3 },               :boo => false }
    #
    #     Hoodoo::Utilities.hash_diff( hash1, hash2 )
    #     # => { :foo => { :bar => [ 2, 3 ] }, :baz => [ true, nil ] }
    #
    #     Hoodoo::Utilities.hash_diff( hash2, hash1 )
    #     # => { :foo => { :bar => [ 3, 2 ] }, :baz => [ nil, true ] }
    #
    # Bear in mind that the difference array contains values of everything
    # different from the first part of the key path where things diverge. So
    # in this case:
    #
    #     hash1 = { :foo => { :bar => { :baz => [ 1, 2, 3 ] } } }
    #     hash2 = {}
    #
    # ...the difference starts all the way up at ":foo". The result is thus
    # *not* a Hash where just the ":baz" array is picked out as a difference;
    # the entire Hash sub-tree is picked out:
    #
    #     diff = Hoodoo::Utilities.hash_diff( hash1, hash2 )
    #     # => { :foo => [ { :bar => { :baz => [ 1, 2, 3 ] } }, nil ] }
    #
    def self.hash_diff( hash1, hash2 )

      # http://stackoverflow.com/questions/1766741/comparing-ruby-hashes
      #
      return ( hash1.keys | hash2.keys ).inject( {} ) do | memo, key |
        unless hash1[ key ] == hash2[ key ]
          if hash1[ key ].kind_of?( Hash ) && hash2[ key ].kind_of?( Hash )
            memo[ key ] = hash_diff( hash1[ key ], hash2[ key ] )
          else
            memo[ key ] = [ hash1[ key ], hash2[ key ] ]
          end
        end

        memo
      end
    end

    # Convert a (potentially nested) Hash into an array of entries which
    # represent its keys, with the notation "foo.bar.baz" for nested hashes.
    #
    # +hash+:: Input Hash.
    #
    # Example:
    #
    #     hash = { :foo => 1, :bar => { :baz => 2, :boo => { :hello => :world } } }
    #
    #     Hoodoo::Utilities.hash_key_paths( hash )
    #     # => [ 'foo', 'bar.baz', 'bar.boo.hello' ]
    #
    def self.hash_key_paths( hash )
      return hash.map do | key, value |
        if value.is_a?( Hash )
          hash_key_paths( value ).map do | entry |
            "#{ key }.#{ entry }"
          end
        else
          key.to_s
        end
      end.flatten
    end

    # A very single-purpose method which converts an Array of specifc form
    # into a Hash.
    #
    # The Hash class can already build itself from an Array of tuples, thus:
    #
    #    array = [ [ :one, 1 ], [ :two, 2 ] ]
    #    hash  = Hash[ array ]
    #    # => { :one => 1, :two => 2 }
    #
    # This is fine, but what if the array contains the same key twice?
    #
    #    array = [ [ :one, 1 ], [ :two, 2 ], [ :one, 42 ] ]
    #    hash  = Hash[ array ]
    #    # => { :one => 42, :two => 2 }
    #
    # The later duplicates simply override any former entries. This Array
    # collation method is designed to instead take the tuples and set up a
    # Hash where each key leads to an Array of unique values found in the
    # original, thus:
    #
    #    array = [ [ :one, 1 ], [ :two, 2 ], [ :one, 42 ] ]
    #    Hoodoo::Utilities.collated_hash_from( array )
    #    # => { :one => [ 1, 42 ], :two => [ 2 ] }
    #
    # Note that:
    #
    # * The Hash values are always Arrays, even if they only have one value.
    # * The Array values are unique; duplicates are removed via +uniq!+.
    #
    # +array+:: Array of two-element Arrays. The first element becomes a key
    #           in the returned Hash. The last element is added to an Array
    #           of (unique) values associated with that key. An empty Array
    #           results in an empty Hash; +nil+ is not allowed.
    #
    # +dupes+:: Optional. If omitted, duplicates are removed as described;
    #           if present and +true+, duplicates are allowed.
    #
    # Returns a new Hash as described. The input Array is not modified.
    #
    def self.collated_hash_from( array, dupes = false )
      hash_of_arrays = {}

      array.reduce( hash_of_arrays ) do | memo, sub_array |
        memo[ sub_array.first ] = ( memo[ sub_array.first ] || [] ) << sub_array.last
        memo
      end

      hash_of_arrays.values.collect( &:uniq! ) unless dupes == true
      return hash_of_arrays
    end

    # Is a parameter convertable to an integer cleanly? Returns the integer
    # value if so, else +nil+.
    #
    # +value+:: Value to check, e.g. 2, "44", :'55' (yields 2, 44, 55) or
    #           "hello", Time.now (yields nil, nil).
    #
    def self.to_integer?( value )
      value = value.to_s
      value.to_i if value.to_i.to_s == value
    end

    # Return a spare TCP port on localhost. This is free at the instant of
    # calling, though of course if you have anything in other local machine
    # processes/threads running which might start using ports at any moment,
    # there's a chance of the free port getting claimed in between you asking
    # for it and it being returned. This utility method is usually therefore
    # used for test environments only.
    #
    def self.spare_port

      # http://stackoverflow.com/questions/5985822/how-do-you-find-a-random-open-port-in-ruby
      #
      socket = Socket.new( :INET, :STREAM, 0 )
      socket.bind( Addrinfo.tcp( '127.0.0.1', 0 ) )
      port = socket.local_address.ip_port
      socket.close

      return port
    end

    # Is the given String a valid ISO 8601 subset date and time as accepted by
    # (for example) Hoodoo API calls?
    #
    # +str+:: Value to check
    #
    # Returns a DateTime instance holding the parsed result if a valid ISO
    # 8601 subset date and time, else +false+.
    #
    def self.valid_iso8601_subset_datetime?( str )
      return false unless str.is_a?( String ) || str.is_a?( Symbol )

      # Relies on Ruby evaluation behaviour and operator precedence - "'foo'
      # && true" => true, but "true && 'foo'" => 'foo'. Don't use "and" here!

      value = begin
        ( DATETIME_ISO8601_SUBSET_REGEXP =~ str.to_s ) == 0 &&
        str.size > 10                                       &&
        ::DateTime.parse( str )

      rescue ArgumentError
      end

      return value.is_a?( ::DateTime ) && value
    end

    # Is the given String a valid ISO 8601 subset date (no time) as accepted
    # by (for example) Hoodoo API calls?
    #
    # +str+:: Value to check
    #
    # Returns a Date instance holding the parsed result if a valid ISO 8601
    # subset date, else +false+.
    #
    def self.valid_iso8601_subset_date?( str )
      return false unless str.is_a?( String ) || str.is_a?( Symbol )

      # Same reliance as 'valid_iso8601_subset_datetime'?.

      value = begin
        ( DATE_ISO8601_SUBSET_REGEXP =~ str.to_s ) == 0 &&
        str.size == 10                                  &&
        ::Date.parse( str )

      rescue ArgumentError
      end

      return value.is_a?( ::Date ) && value
    end

    # Is the given Time, DateTime or String instance specifying a date-time
    # that is in the future relevant to this executing environment's concept
    # of "now", allowing for +CLOCK_DRIFT_TOLERANCE+? Returns +true+ if so,
    # else +false+.
    #
    # Future date (clock drift) tolerance is specified in seconds using the
    # +HOODOO_CLOCK_DRIFT_TOLERANCE+ environment variable. The default is 30
    # seconds, as described in the relevant Hoodoo Guide:
    #
    #   http://loyaltynz.github.io/hoodoo/guides_1000_env_vars.html#hoodoo_clock_drift_tolerance
    #
    # +input+:: A value that's passed to ::rationalise_datetime with the
    #           result checked against `now` allowing for clock drift.
    #
    # +backdated_to+:: Optional. The "now" of the context, defaulting to
    #                  +DateTime.now+.
    #
    # If the given input or `backdated_to` is not parseable as a date-time like
    # object, then the method it will throw a RuntimeError exception via
    # ::rationalise_datetime.
    #
    def self.is_in_future?( input, backdated_to=DateTime.now )

      # See also ::clear_clock_drift_configuration_cache!.
      #
      @@clock_drift_tolerance ||= (
        ENV[ 'HOODOO_CLOCK_DRIFT_TOLERANCE' ].nil? ?
                                                30 :
        ENV[ 'HOODOO_CLOCK_DRIFT_TOLERANCE' ].to_i
      )

      value = self.rationalise_datetime( input )

      backdated_now = self.rationalise_datetime( backdated_to )

      # Unlike Time, integer addition to DateTime adds days. There are 86400
      # seconds per day, so below we add @@clock_drift_tolerance seconds.
      #
      value > backdated_now + Rational(@@clock_drift_tolerance, 86400)

    end

    # This method is intended really just for testing purposes; it clears the
    # internal cache of clock drift tolerance read from environment variable
    # +HOODOO_CLOCK_DRIFT_TOLERANCE+.
    #
    def self.clear_clock_drift_configuration_cache!
      @@clock_drift_tolerance = nil
    end

    # Returns an ISO 8601 String equivalent of the given Time, Date or
    # DateTime instance as a full date-time with UTC timezone, with
    # "standard high precision" (for rendeirng consistency), subject to
    # Ruby port / OS support abilities. At the time of writing, 6 decimal
    # places are included.
    #
    def self.standard_datetime( date_or_time_or_date_time )
      date_or_time_or_date_time.to_time.utc.iso8601( 6 )
    end

    # Returns an ISO 8601 String equivalent of the given Time or DateTime
    # instance, with nanosecond precision (subject to Ruby port / OS support).
    # This is nothing more than a standardised central interface on calling
    # Ruby's <tt>Time/DateTime#iso8601( 9 )</tt>, to avoid the risk of lots of
    # variable length precision times floating around by authors picking their
    # own arbitrary precision parameters.
    #
    # +date_time+:: Ruby Time or DateTime instance to convert to an ISO 8601
    #               String with nanosecond precision.
    #
    def self.nanosecond_iso8601( time_or_date_time )
      time_or_date_time.iso8601( 9 )
    end

    # Turn a given value of various types into a DateTime instance or +nil+.
    # If the input value is not +nil+, a DateTime instance, a Time instance,
    # a Date instance or something else that <tt>DateTime.parse</tt> can
    # handle, the method will throw a RuntimeError exception.
    #
    # +input+:: A Time, Date or DateTime instance, or a String that can be
    #           converted to a DateTime instance; in these cases, an
    #           equivalent DateTime is returned. If +nil+, returns +nil+.
    #
    def self.rationalise_datetime( input )
      begin
        if input.nil? || input.is_a?( DateTime )
          input
        elsif input.is_a?( Time ) || input.is_a?( Date )
          input.to_datetime
        else
          DateTime.parse( input )
        end

      rescue
        raise "Hoodoo::Utilities\#rationalise_datetime: Invalid parameter '#{ input }'"

      end
    end
  end
end
