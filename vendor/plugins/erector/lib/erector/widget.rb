module Erector
  
  # A Widget is the center of the Erector universe. 
  #
  # To create a widget, extend Erector::Widget and implement the +content+
  # method. Inside this method you may call any of the tag methods like +span+
  # or +p+ to emit HTML/XML tags. 
  #  
  # You can also define a widget on the fly by passing a block to +new+. This
  # block will get executed when the widget's +content+ method is called.
  #
  # To render a widget from the outside, instantiate it and call its +to_s+
  # method.
  #
  # A widget's +new+ method optionally accepts an options hash. Entries in
  # this hash are converted to instance variables, and +attr_reader+ accessors
  # are defined for each.
  #
  # You can add runtime input checking via the +needs+ macro. See #needs. 
  # This mechanism is meant to ameliorate development-time confusion about
  # exactly what parameters are supported by a given widget, avoiding
  # confusing runtime NilClass errors.
  #  
  # To call one widget from another, inside the parent widget's +content+
  # method, instantiate the child widget and call the +widget+ method. This
  # assures that the same output stream is used, which gives better
  # performance than using +capture+ or +to_s+. It also preserves the
  # indentation and helpers of the enclosing class.
  #  
  # In this documentation we've tried to keep the distinction clear between
  # methods that *emit* text and those that *return* text. "Emit" means that
  # it writes to the output stream; "return" means that it returns a string
  # like a normal method and leaves it up to the caller to emit that string if
  # it wants.
  class Widget
    extend Erector::Externals # 'extend'ing since they're class methods, not instance methods
    
    class << self
      def all_tags
        Erector::Widget.full_tags + Erector::Widget.empty_tags
      end

      # Tags which are always self-closing. Click "[Source]" to see the full list.
      def empty_tags
        ['area', 'base', 'br', 'col', 'frame', 
        'hr', 'img', 'input', 'link', 'meta']
      end

      # Tags which can contain other stuff. Click "[Source]" to see the full list.
      def full_tags
        [
          'a', 'abbr', 'acronym', 'address', 'article', 'aside', 'audio',
          'b', 'bdo', 'big', 'blockquote', 'body', 'button', 
          'canvas', 'caption', 'center', 'cite', 'code', 'colgroup', 'command',
          'datalist', 'dd', 'del', 'details', 'dfn', 'dialog', 'div', 'dl', 'dt',
          'em', 'embed',
          'fieldset', 'figure', 'footer', 'form', 'frameset',
          'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'head', 'header', 'hgroup', 'html', 'i',
          'iframe', 'ins', 'keygen', 'kbd', 'label', 'legend', 'li',
          'map', 'mark', 'meter',
          'nav', 'noframes', 'noscript',
          'object', 'ol', 'optgroup', 'option',
          'p', 'param', 'pre', 'progress',
          'q', 'ruby', 'rt', 'rp', 's',
          'samp', 'script', 'section', 'select', 'small', 'source', 'span', 'strike',
          'strong', 'style', 'sub', 'sup',
          'table', 'tbody', 'td', 'textarea', 'tfoot',
          'th', 'thead', 'time', 'title', 'tr', 'tt', 'u', 'ul',
          'var', 'video'
        ]
      end

      def def_empty_tag_method(tag_name)
        self.class_eval(<<-SRC, __FILE__, __LINE__)
          def #{tag_name}(*args, &block)
            __empty_element__('#{tag_name}', *args, &block)
          end
        SRC
      end

      def def_full_tag_method(tag_name)
        self.class_eval(<<-SRC, __FILE__, __LINE__)
          def #{tag_name}(*args, &block)
              __element__(false, '#{tag_name}', *args, &block)
          end

          def #{tag_name}!(*args, &block)
            __element__(true, '#{tag_name}', *args, &block)
          end
        SRC
      end

      def after_initialize(instance=nil, &blk)
        if blk
          after_initialize_parts << blk
        elsif instance
          if superclass.respond_to?(:after_initialize)
            superclass.after_initialize instance
          end
          after_initialize_parts.each do |part|
            instance.instance_eval &part
          end
        else
          raise ArgumentError, "You must provide either an instance or a block"
        end
      end
      
      protected
      def after_initialize_parts
        @after_initialize_parts ||= []
      end
      
    end

    # Class method by which widget classes can declare that they need certain
    # parameters. If needed parameters are not passed in to #new, then an
    # exception will be thrown (with a hopefully useful message about which
    # parameters are missing). This is intended to catch silly bugs like
    # passing in a parameter called 'name' to a widget that expects a
    # parameter called 'title'. Every variable declared in 'needs' will get an
    # attr_reader accessor declared for it.
    #
    # You can also declare default values for parameters using hash syntax.
    # You can put #needs declarations on multiple lines or on the same line;
    # the only caveat is that if there are default values, they all have to be
    # at the end of the line (so they go into the magic hash parameter).
    #
    # If a widget has no #needs declaration then it will accept any
    # combination of parameters (and make accessors for them) just like
    # normal. In that case there will be no 'attr_reader's declared. If a
    # widget wants to declare that it takes no parameters, use the special
    # incantation "needs nil" (and don't declare any other needs, or kittens
    # will cry).
    #
    # Usage:
    #    class FancyForm < Erector::Widget
    #      needs :title, :show_okay => true, :show_cancel => false
    #      ...
    #    end
    #  
    # That means that
    #   FancyForm.new(:title => 'Login')
    # will succeed, as will
    #   FancyForm.new(:title => 'Login', :show_cancel => true)
    # but
    #   FancyForm.new(:name => 'Login')
    # will fail.
    #
    def self.needs(*args)
      args.each do |arg|
        (@needs ||= []) << (arg.nil? ? nil : (arg.is_a? Hash) ? arg : arg.to_sym)
      end
    end

    protected
    def self.get_needs
      @needs ||= []

      ancestors[1..-1].inject(@needs.dup) do |needs, ancestor|
        needs.push(*ancestor.get_needs) if ancestor.respond_to?(:get_needs)
        needs
      end
    end

    def self.get_needed_variables
      get_needs.map{|need| need.is_a?(Hash) ? need.keys : need}.flatten
    end

    def self.get_needed_defaults
      get_needs.select{|need| need.is_a? Hash}
    end

    public
    @@prettyprint_default = false
    def prettyprint_default
      @@prettyprint_default
    end

    def self.prettyprint_default=(enabled)
      @@prettyprint_default = enabled
    end

    NON_NEWLINEY = {'i' => true, 'b' => true, 'small' => true,
      'img' => true, 'span' => true, 'a' => true,
      'input' => true, 'textarea' => true, 'button' => true, 'select' => true
    }

    SPACES_PER_INDENT = 2

    RESERVED_INSTANCE_VARS = [:helpers, :assigns, :block, :output, :prettyprint, :indentation, :at_start_of_line]

    attr_reader *RESERVED_INSTANCE_VARS
    attr_reader :parent
    attr_writer :block
    
    def initialize(assigns={}, &block)
      unless assigns.is_a? Hash
        raise "Erector's API has changed. Now you should pass only an options hash into Widget.new; the rest come in via to_s, or by using #widget."
      end
      @assigns = assigns
      assign_instance_variables(assigns)
      unless @parent
        @parent = block ? eval("self", block.binding) : nil
      end
      @block = block
      self.class.after_initialize self
    end

#-- methods for other classes to call, left public for ease of testing and documentation
#++

    protected
    def context(parent, output, prettyprint = false, indentation = 0, helpers = nil)
      #TODO: pass in options hash, maybe, instead of parameters
      original_parent = @parent
      original_output = @output
      original_indendation = @indentation
      original_helpers = @helpers
      original_prettyprint = @prettyprint
      @parent = parent
      @output = output
      @at_start_of_line = true
      raise "indentation must be a number, not #{indentation.inspect}" unless indentation.is_a? Fixnum
      @indentation = indentation
      @helpers = helpers
      @prettyprint = prettyprint
      yield
    ensure
      @parent = original_parent
      @output = original_output
      @indentation = original_indendation
      @helpers = original_helpers
      @prettyprint = original_prettyprint
    end

    public
    def assign_instance_variables (instance_variables)
      needed = self.class.get_needed_variables
      assigned = []
      instance_variables.each do |name, value|
        unless needed.empty? || needed.include?(name)
          raise "Unknown parameter '#{name}'. #{self.class.name} only accepts #{needed.join(', ')}"
        end
        assign_instance_variable(name, value)
        assigned << name
      end

      # set variables with default values
      self.class.get_needed_defaults.each do |hash|
        hash.each_pair do |name, value|
          unless assigned.include?(name)
            assign_instance_variable(name, value)
            assigned << name
          end
        end
      end

      missing = needed - assigned
      unless missing.empty? || missing == [nil]
        raise "Missing parameter#{missing.size == 1 ? '' : 's'}: #{missing.join(', ')}"
      end
    end
    
    def assign_instance_variable (name, value)
      raise ArgumentError, "Sorry, #{name} is a reserved variable name for Erector. Please choose a different name." if RESERVED_INSTANCE_VARS.include?(name)
      name = name.to_s
      ivar_name = (name[0..0] == '@' ? name : "@#{name}")
      instance_variable_set(ivar_name, value)
    end
    
    # Render (like to_s) but adding newlines and indentation.
    # This is a convenience method; you may just want to call to_s(:prettyprint => true)
    # so you can pass in other rendering options as well.  
    def to_pretty
      to_s(:prettyprint => true)
    end
    
    # Render (like to_s) but stripping all tags.
    def to_text
      CGI.unescapeHTML(to_s(:prettyprint => false).gsub(/<[^>]*>/, ''))
    end

    # Entry point for rendering a widget (and all its children). This method
    # creates a new output string (if necessary), calls this widget's #content
    # method and returns the string.
    #
    # Options:
    # output:: the string to output to. Default: a new empty string
    # prettyprint:: whether Erector should add newlines and indentation.
    #               Default: the value of prettyprint_default (which is false
    #               by default). 
    # indentation:: the amount of spaces to indent. Ignored unless prettyprint
    #               is true.
    # helpers:: a helpers object containing utility methods. Usually this is a
    #           Rails view object.
    # content_method_name:: in case you want to call a method other than
    #                       #content, pass its name in here.
    def to_s(options = {}, &blk)
      raise "Erector::Widget#to_s now takes an options hash, not a symbol. Try calling \"to_s(:content_method_name=> :#{options})\"" if options.is_a? Symbol
      _render(options, &blk).to_s
    end
    
    # Entry point for rendering a widget (and all its children). Same as #to_s
    # only it returns an array, for theoretical performance improvements when using a
    # Rack server (like Sinatra or Rails Metal).
    #
    # # Options: see #to_s
    def to_a(options = {}, &blk)
      _render({:output => []}.merge(options), &blk).to_a
    end
    
    def _render(options = {}, &blk)
      options = {
        :output => "",  # "" is apparently faster than [] in a long-running process
        :prettyprint => prettyprint_default,
        :indentation => 0,
        :helpers => nil,
        :parent => @parent,
        :content_method_name => :content,
      }.merge(options)
      context(options[:parent], options[:output], options[:prettyprint], options[:indentation], options[:helpers]) do
        send(options[:content_method_name], &blk)
        output
      end
    end
    
    # Template method which must be overridden by all widget subclasses.
    # Inside this method you call the magic #element methods which emit HTML
    # and text to the output string. If you call "super" (or don't override
    # +content+, or explicitly call "call_block") then your widget will
    # execute the block that was passed into its constructor. The semantics of
    # this block are confusing; make sure to read the rdoc for Erector#call_block
    def content
      call_block
    end
    
    # When this method is executed, the default block that was passed in to 
    # the widget's constructor will be executed. The semantics of this 
    # block -- that is, what "self" is, and whether it has access to
    # Erector methods like "div" and "text", and the widget's instance
    # variables -- can be quite confusing. The rule is, most of the time the
    # block is evaluated using "call" or "yield", which means that its scope
    # is that of the caller. So if that caller is not an Erector widget, it
    # will *not* have access to the Erector methods, but it *will* have access 
    # to instance variables and methods of the calling object.
    #   
    # If you want this block to have access to Erector methods then use 
    # Erector::Inline#content or Erector#inline.
    def call_block
      @block.call(self) if @block
    end

    # To call one widget from another, inside the parent widget's +content+
    # method, instantiate the child widget and call its +write_via+ method,
    # passing in +self+. This assures that the same output string is used,
    # which gives better performance than using +capture+ or +to_s+. You can
    # also use the +widget+ method.
    def write_via(parent)
      context(parent, parent.output, parent.prettyprint, parent.indentation, parent.helpers) do
        content
      end
    end

    # Emits a (nested) widget onto the current widget's output stream. Accepts
    # either a class or an instance. If the first argument is a class, then
    # the second argument is a hash used to populate its instance variables.
    # If the first argument is an instance then the hash must be unspecified
    # (or empty). If a block is passed to this method, then it gets set as the
    # rendered widget's block.
    def widget(target, assigns={}, &block)
      child = if target.is_a? Class
        target.new(assigns, &block)
      else
        unless assigns.empty?
          raise "Unexpected second parameter. Did you mean to pass in variables when you instantiated the #{target.class.to_s}?"
        end
        target.block = block unless block.nil?
        target
      end
      child.write_via(self)
    end

    # (Should we make this hidden?)
    def html_escape
      return to_s
    end

#-- methods for subclasses to call
#++

    # Internal method used to emit an HTML/XML element, including an open tag,
    # attributes (optional, via the default hash), contents (also optional),
    # and close tag.
    #
    # Using the arcane powers of Ruby, there are magic methods that call
    # +element+ for all the standard HTML tags, like +a+, +body+, +p+, and so
    # forth. Look at the source of #full_tags for the full list.
    # Unfortunately, this big mojo confuses rdoc, so we can't see each method
    # in this rdoc page, but trust us, they're there.
    #
    # When calling one of these magic methods, put attributes in the default
    # hash. If there is a string parameter, then it is used as the contents.
    # If there is a block, then it is executed (yielded), and the string
    # parameter is ignored. The block will usually be in the scope of the
    # child widget, which means it has access to all the methods of Widget,
    # which will eventually end up appending text to the +output+ string. See
    # how elegant it is? Not confusing at all if you don't think about it.
    #
    def element(*args, &block)
      __element__(false, *args, &block)
    end

    # Like +element+, but string parameters are not escaped.
    def element!(*args, &block)
      __element__(true, *args, &block)
    end

    # Internal method used to emit a self-closing HTML/XML element, including
    # a tag name and optional attributes (passed in via the default hash).
    #
    # Using the arcane powers of Ruby, there are magic methods that call
    # +empty_element+ for all the standard HTML tags, like +img+, +br+, and so
    # forth. Look at the source of #empty_tags for the full list.
    # Unfortunately, this big mojo confuses rdoc, so we can't see each method
    # in this rdoc page, but trust us, they're there.
    #
    def empty_element(*args, &block)
      __empty_element__(*args, &block)
    end

    # Returns an HTML-escaped version of its parameter. Leaves the output
    # string untouched. Note that the #text method automatically HTML-escapes
    # its parameter, so be careful *not* to do something like text(h("2<4"))
    # since that will double-escape the less-than sign (you'll get
    # "2&amp;lt;4" instead of "2&lt;4").
    def h(content)
      content.html_escape
    end

    # Emits an open tag, comprising '<', tag name, optional attributes, and '>'
    def open_tag(tag_name, attributes={})
      indent_for_open_tag(tag_name)
      @indentation += SPACES_PER_INDENT

      output << "<#{tag_name}#{format_attributes(attributes)}>"
      @at_start_of_line = false
    end

    # Emits text.  If a string is passed in, it will be HTML-escaped. If a
    # widget or the result of calling methods such as raw is passed in, the
    # HTML will not be HTML-escaped again. If another kind of object is passed
    # in, the result of calling its to_s method will be treated as a string
    # would be.
    def text(value)
      if value.is_a? Widget
        widget value
      else
        output <<(value.html_escape)
      end
      @at_start_of_line = false
      nil
    end

    # Returns text which will *not* be HTML-escaped.
    def raw(value)
      RawString.new(value.to_s)
    end

    # Emits text which will *not* be HTML-escaped. Same effect as text(raw(s))
    def text!(value)
      text raw(value)
    end

    alias rawtext text!

    # Returns a copy of value with spaces replaced by non-breaking space characters.
    # With no arguments, return a single non-breaking space.
    # The output uses the escaping format '&#160;' since that works
    # in both HTML and XML (as opposed to '&nbsp;' which only works in HTML).
    def nbsp(value = " ")
      raw(value.html_escape.gsub(/ /,'&#160;'))
    end
    
    # Return a character given its unicode code point or unicode name.
    def character(code_point_or_name)
      if code_point_or_name.is_a?(Symbol)
        found = Erector::CHARACTERS[code_point_or_name]
        if found.nil?
          raise "Unrecognized character #{code_point_or_name}"
        end
        raw("&#x#{sprintf '%x', found};")
      elsif code_point_or_name.is_a?(Integer)
        raw("&#x#{sprintf '%x', code_point_or_name};")
      else
        raise "Unrecognized argument to character: #{code_point_or_name}"
      end
    end

    # Emits a close tag, consisting of '<', '/', tag name, and '>'
    def close_tag(tag_name)
      @indentation -= SPACES_PER_INDENT
      indent()

      output <<("</#{tag_name}>")

      if newliney?(tag_name)
        _newline
      end
    end
    
    # Emits the result of joining the elements in array with the separator.
    # The array elements and separator can be Erector::Widget objects,
    # which are rendered, or strings, which are html-escaped and output.
    def join(array, separator)
      first = true
      array.each do |widget_or_text|
        if !first
          text separator
        end
        first = false
        text widget_or_text
      end
    end

    # Emits an XML instruction, which looks like this: <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    def instruct(attributes={:version => "1.0", :encoding => "UTF-8"})
      output << "<?xml#{format_sorted(sort_for_xml_declaration(attributes))}?>"
    end

    # Emits an HTML comment (&lt;!-- ... --&gt;) surrounding +text+ and/or the output of +block+.
    # see http://www.w3.org/TR/html4/intro/sgmltut.html#h-3.2.4
    #
    # If +text+ is an Internet Explorer conditional comment condition such as "[if IE]",
    # the output includes the opening condition and closing "[endif]". See
    # http://www.quirksmode.org/css/condcom.html
    #
    # Since "Authors should avoid putting two or more adjacent hyphens inside comments,"
    # we emit a warning if you do that.
    def comment(text = '', &block)
      puts "Warning: Authors should avoid putting two or more adjacent hyphens inside comments." if text =~ /--/

      conditional = text =~ /\[if .*\]/

      rawtext "<!--"
      rawtext text
      rawtext ">" if conditional

      if block
        rawtext "\n"
        block.call
        rawtext "\n"
      end

      rawtext "<![endif]" if conditional
      rawtext "-->\n"
    end

    # Creates a whole new output string, executes the block, then converts the
    # output string to a string and returns it as raw text. If at all possible
    # you should avoid this method since it hurts performance, and use
    # +widget+ or +write_via+ instead.
    def capture(&block)
      begin
        original_output = output
        @output = ""
        yield
        raw(output.to_s)
      ensure
        @output = original_output
      end
    end

    full_tags.each do |tag_name|
      def_full_tag_method(tag_name)
    end

    empty_tags.each do |tag_name|
      def_empty_tag_method(tag_name)
    end

    # Emits a javascript block inside a +script+ tag, wrapped in CDATA
    # doohickeys like all the cool JS kids do.
    def javascript(*args, &block)
      if args.length > 2
        raise ArgumentError, "Cannot accept more than two arguments"
      end
      attributes, value = nil, nil
      arg0 = args[0]
      if arg0.is_a?(Hash)
        attributes = arg0
      else
        value = arg0
        arg1 = args[1]
        if arg1.is_a?(Hash)
          attributes = arg1
        end
      end
      attributes ||= {}
      attributes[:type] = "text/javascript"
      open_tag 'script', attributes

      # Shouldn't this be a "cdata" HtmlPart?
      # (maybe, but the syntax is specific to javascript; it isn't
      # really a generic XML CDATA section.  Specifically,
      # ]]> within value is not treated as ending the
      # CDATA section by Firefox2 when parsing text/html,
      # although I guess we could refuse to generate ]]>
      # there, for the benefit of XML/XHTML parsers).
      rawtext "\n// <![CDATA[\n"
      if block
        instance_eval(&block)
      else
        rawtext value
      end
      rawtext "\n// ]]>\n"

      close_tag 'script'
      rawtext "\n"
    end
    
    # Convenience method to emit a css file link, which looks like this:
    # <link href="erector.css" rel="stylesheet" type="text/css" />
    # The parameter is the full contents of the href attribute, including any ".css" extension.
    #
    # If you want to emit raw CSS inline, use the #style method instead.
    def css(href, options = {})
      link({:rel => 'stylesheet', :type => 'text/css', :href => href}.merge(options))
    end
    
    # Convenience method to emit an anchor tag whose href and text are the same,
    # e.g. <a href="http://example.com">http://example.com</a>
    def url(href, options = {})
      a href, ({:href => href}.merge(options))
    end

    # makes a unique id based on the widget's class name and object id
    # that you can use as the HTML id of an emitted element
    def dom_id
      "#{self.class.name.gsub(/:+/,"_")}_#{self.object_id}"
    end

    # emits a jQuery script that is to be run on document ready
    def jquery(txt)
      javascript do
        jquery_ready txt
      end
    end

    protected
    def jquery_ready(txt)
      rawtext "\n"
      rawtext "jQuery(document).ready(function($){\n"
      rawtext txt
      rawtext "\n});"
    end
    
### internal utility methods

protected
    def __element__(raw, tag_name, *args, &block)
      if args.length > 2
        raise ArgumentError, "Cannot accept more than four arguments"
      end
      attributes, value = nil, nil
      arg0 = args[0]
      if arg0.is_a?(Hash)
        attributes = arg0
      else
        value = arg0
        arg1 = args[1]
        if arg1.is_a?(Hash)
          attributes = arg1
        end
      end
      attributes ||= {}
      open_tag tag_name, attributes
      if block && value
        raise ArgumentError, "You can't pass both a block and a value to #{tag_name} -- please choose one."
      end
      if block
        block.call
      elsif raw
        text! value
      else
        text value
      end
      close_tag tag_name
    end

    def __empty_element__(tag_name, attributes={})
      indent_for_open_tag(tag_name)

      output << "<#{tag_name}#{format_attributes(attributes)} />"

      if newliney?(tag_name)
        _newline
      end
    end
    
    def _newline
      return unless @prettyprint      
      output << "\n"
      @at_start_of_line = true
    end

    def indent_for_open_tag(tag_name)
      return unless @prettyprint      
      if !@at_start_of_line && newliney?(tag_name)
        _newline
      end
      indent()
    end

    def indent()
      if @at_start_of_line
        output << " " * [@indentation, 0].max
      end
    end

    def format_attributes(attributes)
      if !attributes || attributes.empty?
        ""
      else
        format_sorted(sorted(attributes))
      end
    end

    def format_sorted(sorted)
      results = ['']
      sorted.each do |key, value|
        if value
          if value.is_a?(Array)
            value = value.flatten
            next if value.empty?
            value = value.join(' ')
          end
          results << "#{key}=\"#{value.html_escape}\""
        end
      end
      return results.join(' ')
    end

    def sorted(attributes)
      stringized = []
      attributes.each do |key, value|
        stringized << [key.to_s, value]
      end
      return stringized.sort
    end

    def sort_for_xml_declaration(attributes)
      # correct order is "version, encoding, standalone" (XML 1.0 section 2.8).
      # But we only try to put version before encoding for now.
      stringized = []
      attributes.each do |key, value|
        stringized << [key.to_s, value]
      end
      return stringized.sort{|a, b| b <=> a}
    end

    def newliney?(tag_name)
      if @prettyprint
        !NON_NEWLINEY.include?(tag_name)
      else
        false
      end
    end

  end
end
