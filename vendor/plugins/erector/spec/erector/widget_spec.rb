require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")
require 'benchmark'

module WidgetSpec
  describe Erector::Widget do
    describe ".all_tags" do
      it "returns set of full and empty tags" do
        Erector::Widget.all_tags.class.should == Array
        Erector::Widget.all_tags.should == Erector::Widget.full_tags + Erector::Widget.empty_tags
      end
    end

    describe "#to_s" do
      class << self
        define_method("invokes #content and returns the string representation of the rendered widget") do
          it "invokes #content and returns the string representation of the rendered widget" do
            widget = Erector.inline do
              div "Hello"
            end
            mock.proxy(widget).content
            widget.to_s.should == "<div>Hello</div>"
          end
        end
      end

      context "when passed no arguments" do
        send "invokes #content and returns the string representation of the rendered widget"
      end

      context "when passed an argument that is #content" do
        send "invokes #content and returns the string representation of the rendered widget"
      end

      context "when passed an argument that is not #content" do
        attr_reader :widget
        before do
          @widget = Erector::Widget.new
          def widget.alternate_content
            div "Hello from Alternate Write"
          end
          mock.proxy(widget).alternate_content
        end

        it "invokes the passed in method name and returns the string representation of the rendered widget" do
          widget.to_s(:content_method_name => :alternate_content).should == "<div>Hello from Alternate Write</div>"
        end

        it "does not invoke #content" do
          dont_allow(widget).content
          widget.to_s(:content_method_name => :alternate_content)
        end
      end
    end

    describe "#to_a" do
      it "returns an array" do
        widget = Erector.inline do
          div "Hello"
        end
        widget.to_a.should == ["<div>", "Hello", "</div>"]
      end

    # removing this, since oddly, when i run this test solo it works, but when
    # i run it as part of a rake suite, i get the opposite result -Alex
    #   it "runs faster than using a string as the output" do
    #     widget = Erector.inline do
    #       1000.times do |i|
    #         div "Lorem ipsum dolor sit amet #{i}, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est #{i} laborum."
    #       end
    #     end
    # 
    #     times = 20
    #     time_for_to_a = Benchmark.measure { times.times { widget.to_a } }.total
    #     # puts "to_a: #{time_for_to_a}"
    #     time_for_string = Benchmark.measure { times.times { widget.to_s(:output => "") } }.total
    #     # puts "to_s(''): #{time_for_string}"
    #     
    #     percent_faster = (((time_for_string - time_for_to_a) / time_for_string)*100)
    #     # puts ("%.1f%%" % percent_faster)
    # 
    #     (time_for_to_a <= time_for_string).should be_true
    #   end
    end

    describe "#instruct" do
      it "when passed no arguments; returns an XML declaration with version 1 and utf-8" do
        html = Erector.inline do
          instruct
          # version must precede encoding, per XML 1.0 4th edition (section 2.8)
        end.to_s.should == "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
      end
    end

    describe '#widget' do
      context "basic nesting" do
        before do
          class Parent < Erector::Widget
            def content
              text 1
              widget Child do
                text 2
                third
              end
            end

            def third
              text 3
            end
          end

          class Child < Erector::Widget
            def content
              super
            end
          end
        end

        it "renders nested widgets in the correct order" do
          Parent.new.to_s.should == '123'
        end
      end
      
    end

    describe "#widget" do
      class Orphan < Erector::Widget
        def content
          p @name
        end
      end
      
      context "when passed a class" do
        it "renders it" do
          Erector.inline do
            div do
              widget Orphan, :name => "Annie"
            end
          end.to_s.should == "<div><p>Annie</p></div>"
        end
      end
      
      context "when passed an instance" do
        it "renders it" do
          Erector.inline do
            div do
              widget Orphan.new(:name => "Oliver")
            end
          end.to_s.should == "<div><p>Oliver</p></div>"
        end
      end

      context "when nested" do
        it "renders the tag around the rest of the block" do
          parent_widget = Class.new(Erector::Widget) do
            def content
              div :id => "parent_widget" do
                super
              end
            end
          end
          
          child_widget = Class.new(Erector::Widget) do
            def content
              div :id => "child_widget" do
                super
              end
            end
          end

          grandchild = Class.new(Erector::InlineWidget) do
            needs :parent_widget, :child_widget
            def content
              widget(@parent_widget) do
                widget(@child_widget) do
                  div :id => "grandchild"
                end
              end
            end
          end

          grandchild.new(:parent_widget => parent_widget, :child_widget => child_widget).to_s.should == '<div id="parent_widget"><div id="child_widget"><div id="grandchild"></div></div></div>'

          pending "pretty-print indentation is messed up with nesting" do
          grandchild.new(:parent_widget => parent_widget, :child_widget => child_widget).to_pretty.should == 
          "<div id=\"parent_widget\">\n" + 
          "  <div id=\"child_widget\">\n" + 
          "    <div id=\"grandchild\"></div>\n" + 
          "  </div>\n" +
          "</div>"
          end

        end
        
        it "passes a pointer to the child object back into the parent object's block" do
          child_widget = Erector::Widget.new
          
          class Parent < Erector::Widget 
            needs :child_widget
            def content
              div do
                widget @child_widget do |child|
                  b child.dom_id
                end
              end
            end
          end
          
          Parent.new(:child_widget => child_widget).to_s.should == "<div><b>#{child_widget.dom_id}</b></div>"
          
        end
        
      end
    end
    
    describe "#call_block" do
      it "calls the block with a pointer to self" do
        inside_arg = nil
        inside_self = nil
        x = Erector::Widget.new do |y|
          inside_arg = y.object_id
          inside_self = self.object_id
        end
        x.call_block
        # inside the block...
        inside_arg.should == x.object_id # the argument is the child
        inside_self.should == self.object_id # and self is the parent
      end
    end

    describe "#element" do
      context "when receiving one argument" do
        it "returns an empty element" do
          Erector.inline do
            element('div')
          end.to_s.should == "<div></div>"
        end
      end

      context "with a attribute hash" do
        it "returns an empty element with the attributes" do
          html = Erector.inline do
            element(
              'div',
              :class => "foo bar",
              :style => "display: none; color: white; float: left;",
              :nil_attribute => nil
            )
          end.to_s
          doc = Nokogiri::HTML(html)
          div = doc.at('div')
          div[:class].should == "foo bar"
          div[:style].should == "display: none; color: white; float: left;"
          div[:nil_attribute].should be_nil
        end
      end

      context "with an array of CSS classes" do
        it "returns a tag with the classes separated" do
          Erector.inline do
            element('div', :class => [:foo, :bar])
          end.to_s.should == "<div class=\"foo bar\"></div>";
        end
      end

      context "with an array of CSS classes as strings" do
        it "returns a tag with the classes separated" do
          Erector.inline do
            element('div', :class => ['foo', 'bar'])
          end.to_s.should == "<div class=\"foo bar\"></div>";
        end
      end

      context "with a CSS class which is a string" do
        it "just use that as the attribute value" do
          Erector.inline do
            element('div', :class => "foo bar")
          end.to_s.should == "<div class=\"foo bar\"></div>";
        end
      end

      context "with an empty array of CSS classes" do
        it "does not emit a class attribute" do
          Erector.inline do
            element('div', :class => [])
          end.to_s.should == "<div></div>"
        end
      end

      context "with many attributes" do
        it "alphabetize them" do
            Erector.inline do
              empty_element('foo', :alpha => "", :betty => "5", :aardvark => "tough",
                :carol => "", :demon => "", :erector => "", :pi => "3.14", :omicron => "", :zebra => "", :brain => "")
            end.to_s.should == "<foo aardvark=\"tough\" alpha=\"\" betty=\"5\" brain=\"\" carol=\"\" demon=\"\" " \
               "erector=\"\" omicron=\"\" pi=\"3.14\" zebra=\"\" />";
          end
      end

      context "with inner tags" do
        it "returns nested tags" do
          widget = Erector.inline do
            element 'div' do
              element 'div'
            end
          end
          widget.to_s.should == '<div><div></div></div>'
        end
      end

      context "with text" do
        it "returns element with inner text" do
          Erector.inline do
            element 'div', 'test text'
          end.to_s.should == "<div>test text</div>"
        end
      end

      context "with object other than hash" do
        it "returns element with inner text == object.to_s" do
          object = ['a', 'b']
          Erector.inline do
            element 'div', object
          end.to_s.should == "<div>#{object.to_s}</div>"
        end
      end

      context "with parameters and block" do
        it "returns element with inner html and attributes" do
          Erector.inline do
            element 'div', 'class' => "foobar" do
              element 'span', 'style' => 'display: none;'
            end
          end.to_s.should == '<div class="foobar"><span style="display: none;"></span></div>'
        end
      end

      context "with content and parameters" do
        it "returns element with content as inner html and attributes" do
          Erector.inline do
            element 'div', 'test text', :style => "display: none;"
          end.to_s.should == '<div style="display: none;">test text</div>'
        end
      end

      context "with more than three arguments" do
        it "raises ArgumentError" do
          proc do
            Erector.inline do
              element 'div', 'foobar', {}, 'fourth'
            end.to_s
          end.should raise_error(ArgumentError)
        end
      end

      it "renders the proper full tags" do
        Erector::Widget.full_tags.each do |tag_name|
          expected = "<#{tag_name}></#{tag_name}>"
          actual = Erector.inline do
            send(tag_name)
          end.to_s
          begin
            actual.should == expected
          rescue Spec::Expectations::ExpectationNotMetError => e
            puts "Expected #{tag_name} to be a full element. Expected #{expected}, got #{actual}"
            raise e
          end
        end
      end

      describe "quoting" do
        context "when outputting text" do
          it "quotes it" do
            Erector.inline do
              element 'div', 'test &<>text'
            end.to_s.should == "<div>test &amp;&lt;&gt;text</div>"
          end
        end

        context "when outputting text via text" do
          it "quotes it" do
            Erector.inline do
              element 'div' do
                text "test &<>text"
              end
            end.to_s.should == "<div>test &amp;&lt;&gt;text</div>"
          end
        end

        context "when outputting attribute value" do
          it "quotes it" do
            Erector.inline do
              element 'a', :href => "foo.cgi?a&b"
            end.to_s.should == "<a href=\"foo.cgi?a&amp;b\"></a>"
          end
        end

        context "with raw text" do
          it "does not quote it" do
            Erector.inline do
              element 'div' do
                text raw("<b>bold</b>")
              end
            end.to_s.should == "<div><b>bold</b></div>"
          end
        end

        context "with raw text and no block" do
          it "does not quote it" do
            Erector.inline do
              element 'div', raw("<b>bold</b>")
            end.to_s.should == "<div><b>bold</b></div>"
          end
        end

        context "with raw attribute" do
          it "does not quote it" do
            Erector.inline do
              element 'a', :href => raw("foo?x=&nbsp;")
            end.to_s.should == "<a href=\"foo?x=&nbsp;\"></a>"
          end
        end

        context "with quote in attribute" do
          it "quotes it" do
            Erector.inline do
              element 'a', :onload => "alert(\"foo\")"
            end.to_s.should == "<a onload=\"alert(&quot;foo&quot;)\"></a>"
          end
        end
      end

      context "with a non-string, non-raw" do
        it "calls to_s and quotes" do
          Erector.inline do
            element 'a' do
              text [7, "foo&bar"]
            end
          end.to_s.should == "<a>7foo&amp;bar</a>"
        end
      end
    end

    describe "#empty_element" do
      context "when receiving attributes" do
        it "renders an empty element with the attributes" do
          Erector.inline do
            empty_element 'input', :name => 'foo[bar]'
          end.to_s.should == '<input name="foo[bar]" />'
        end
      end

      context "when not receiving attributes" do
        it "renders an empty element without attributes" do
          Erector.inline do
            empty_element 'br'
          end.to_s.should == '<br />'
        end
      end

      it "renders the proper empty-element tags" do
        Erector::Widget.empty_tags.each do |tag_name|
          expected = "<#{tag_name} />"
          actual = Erector.inline do
            send(tag_name)
          end.to_s
          begin
            actual.should == expected
          rescue Spec::Expectations::ExpectationNotMetError => e
            puts "Expected #{tag_name} to be an empty-element tag. Expected #{expected}, got #{actual}"
            raise e
          end
        end
      end
    end
    
    def capturing_output
      output = StringIO.new
      $stdout = output
      yield
      output.string
    ensure
      $stdout = STDOUT
    end

    describe "#comment" do
      it "emits a single line comment when receiving a string" do
        Erector.inline do
          comment "foo"
        end.to_s.should == "<!--foo-->\n"
      end

      it "emits a multiline comment when receiving a block" do
        Erector.inline do
          comment do
            text "Hello"
            text " world!"
          end
        end.to_s.should == "<!--\nHello world!\n-->\n"
      end

      it "emits a multiline comment when receiving a string and a block" do
        Erector.inline do
          comment "Hello" do
            text " world!"
          end
        end.to_s.should == "<!--Hello\n world!\n-->\n"
      end

      # see http://www.w3.org/TR/html4/intro/sgmltut.html#h-3.2.4
      it "does not HTML-escape character references" do
        Erector.inline do
          comment "&nbsp;"
        end.to_s.should == "<!--&nbsp;-->\n"
      end
      
      # see http://www.w3.org/TR/html4/intro/sgmltut.html#h-3.2.4
      # "Authors should avoid putting two or more adjacent hyphens inside comments."
      it "warns if there's two hyphens in a row" do
        capturing_output do
          Erector.inline do
            comment "he was -- awesome!"
          end.to_s.should == "<!--he was -- awesome!-->\n"
        end.should == "Warning: Authors should avoid putting two or more adjacent hyphens inside comments.\n"
      end

      it "renders an IE conditional comment with endif when receiving an if IE" do
        Erector.inline do
          comment "[if IE]" do
            text "Hello IE!"
          end
        end.to_s.should == "<!--[if IE]>\nHello IE!\n<![endif]-->\n"
      end

      it "doesn't render an IE conditional comment if there's just some text in brackets" do
        Erector.inline do
          comment "[puppies are cute]"
        end.to_s.should == "<!--[puppies are cute]-->\n"
      end

    end

    describe "#nbsp" do
      it "turns consecutive spaces into consecutive non-breaking spaces" do
        Erector.inline do
          text nbsp("a  b")
        end.to_s.should == "a&#160;&#160;b"
      end

      it "works in text context" do
        Erector.inline do
          element 'a' do
            text nbsp("&<> foo")
          end
        end.to_s.should == "<a>&amp;&lt;&gt;&#160;foo</a>"
      end

      it "works in attribute value context" do
        Erector.inline do
          element 'a', :href => nbsp("&<> foo")
        end.to_s.should == "<a href=\"&amp;&lt;&gt;&#160;foo\"></a>"
      end
      
      it "defaults to a single non-breaking space if given no argument" do
        Erector.inline do
          text nbsp
        end.to_s.should == "&#160;"
      end

    end

    describe "#character" do
      it "renders a character given the codepoint number" do
        Erector.inline do
          text character(160)
        end.to_s.should == "&#xa0;"
      end
      
      it "renders a character given the unicode name" do
        Erector.inline do
          text character(:right_arrow)
        end.to_s.should == "&#x2192;"
      end

      it "renders a character above 0xffff" do
        Erector.inline do
          text character(:old_persian_sign_ka)
        end.to_s.should == "&#x103a3;"
      end

      it "throws an exception if a name is not recognized" do
        lambda {
          Erector.inline do
            text character(:no_such_character_name)
          end.to_s
        }.should raise_error("Unrecognized character no_such_character_name")
      end

      it "throws an exception if passed something besides a symbol or integer" do
        # Perhaps calling to_s would be more ruby-esque, but that seems like it might
        # be pretty confusing when this method can already take either a name or number
        lambda {
          Erector.inline do
            text character([])
          end.to_s
        }.should raise_error("Unrecognized argument to character: ")
      end
    end

    describe "#join" do

      it "empty array means nothing to join" do
        Erector.inline do
          join [], Erector::Widget.new { text "x" }
        end.to_s.should == ""
      end
      
      it "larger example with two tabs" do
        Erector.inline do
          tab1 = 
            Erector.inline do
              a "Upload document", :href => "/upload"
            end
          tab2 =
            Erector.inline do
              a "Logout", :href => "/logout"
            end
          join [tab1, tab2],
            Erector::Widget.new { text nbsp(" |"); text " " }
        end.to_s.should == 
          '<a href="/upload">Upload document</a>&#160;| <a href="/logout">Logout</a>'
      end
      
      it "plain string as join separator means pass it to text" do
        Erector.inline do
          join [
            Erector::Widget.new { text "x" },
            Erector::Widget.new { text "y" }
          ], "<>"
        end.to_s.should == "x&lt;&gt;y"
      end

      it "plain string as item to join means pass it to text" do
        Erector.inline do
          join [
            "<",
            "&"
          ], Erector::Widget.new { text " + " }
        end.to_s.should == "&lt; + &amp;"
      end

    end

    describe '#h' do
      before do
        @widget = Erector::Widget.new
      end

      it "escapes regular strings" do
        @widget.h("&").should == "&amp;"
      end

      it "does not escape raw strings" do
        @widget.h(@widget.raw("&")).should == "&"
      end
    end

    describe 'escaping' do
      plain = 'if (x < y && x > z) alert("don\'t stop");'
      escaped = "if (x &lt; y &amp;&amp; x &gt; z) alert(&quot;don't stop&quot;);"

      describe "#text" do
        it "does HTML escape its param" do
          Erector.inline { text plain }.to_s.should == escaped
        end
      end
      describe "#rawtext" do
        it "doesn't HTML escape its param" do
          Erector.inline { rawtext plain }.to_s.should == plain
        end
      end
      describe "#text!" do
        it "doesn't HTML escape its param" do
          Erector.inline { text! plain }.to_s.should == plain
        end
      end
      describe "#element" do
        it "does HTML escape its param" do
          Erector.inline { element "foo", plain }.to_s.should == "<foo>#{escaped}</foo>"
        end
      end
      describe "#element!" do
        it "doesn't HTML escape its param" do
          Erector.inline { element! "foo", plain }.to_s.should == "<foo>#{plain}</foo>"
        end
      end
    end

    describe "#javascript" do
      context "when receiving a block" do
        it "renders the content inside of script text/javascript tags" do
          expected = <<-EXPECTED
            <script type="text/javascript">
            // <![CDATA[
            if (x < y && x > z) alert("don't stop");
            // ]]>
            </script>
          EXPECTED
          expected.gsub!(/^            /, '')
          Erector.inline do
            javascript do
              rawtext 'if (x < y && x > z) alert("don\'t stop");'
            end
          end.to_s.should == expected
        end
      end

      it "renders the raw content inside script tags when given text" do
        expected = <<-EXPECTED
          <script type="text/javascript">
          // <![CDATA[
          alert("&<>'hello");
          // ]]>
          </script>
        EXPECTED
        expected.gsub!(/^          /, '')
        Erector.inline do
          javascript('alert("&<>\'hello");')
        end.to_s.should == expected
      end

      context "when receiving a params hash" do
        it "renders a source file" do
          html = Erector.inline do
            javascript(:src => "/my/js/file.js")
          end.to_s
          doc = Nokogiri::HTML(html)
          doc.at("script")[:src].should == "/my/js/file.js"
        end
      end

      context "when receiving text and a params hash" do
        it "renders a source file" do
          html = Erector.inline do
            javascript('alert("&<>\'hello");', :src => "/my/js/file.js")
          end.to_s
          doc = Nokogiri::HTML(html)
          script_tag = doc.at('script')
          script_tag[:src].should == "/my/js/file.js"
          script_tag.inner_html.should include('alert("&<>\'hello");')
        end
      end

      context "with too many arguments" do
        it "raises ArgumentError" do
          proc do
            Erector.inline do
              javascript 'foobar', {}, 'fourth'
            end.to_s
          end.should raise_error(ArgumentError)
        end
      end
    end

    describe "#css" do
      it "makes a link when passed a string" do
        Erector.inline do
          css "erector.css"
        end.to_s.should == "<link href=\"erector.css\" rel=\"stylesheet\" type=\"text/css\" />"
      end

      it "accepts a media attribute" do
        Erector.inline do
          css "print.css", :media => "print"
        end.to_s.should == "<link href=\"print.css\" media=\"print\" rel=\"stylesheet\" type=\"text/css\" />"
      end
    end

    describe "#to_text" do
      it "strips tags" do
        Erector.inline do
          div "foo"
        end.to_text.should == "foo"
      end

      it "unescapes named entities" do
        s = "my \"dog\" has fleas & <ticks>"
        Erector.inline do
          text s
        end.to_text.should == s
      end

      it "ignores >s inside attribute strings" do
        Erector.inline do
          a "foo", :href => "http://example.com/x>y"
        end.to_text.should == "foo"
      end

      it "doesn't inherit unwanted pretty-printed whitespace (i.e. it turns off prettyprinting)" do
        old_default = Erector::Widget.new.prettyprint_default
        begin
          Erector::Widget.prettyprint_default = true
          Erector.inline do
            div { div { div "foo" } }
          end.to_text.should == "foo"
        ensure
          Erector::Widget.prettyprint_default = old_default
        end
      end
    end

    describe "#url" do
      it "renders an anchor tag with the same href and text" do
        Erector.inline do
          url "http://example.com"
        end.to_s.should == "<a href=\"http://example.com\">http://example.com</a>"
      end

      it "accepts extra attributes" do
        Erector.inline do
          url "http://example.com", :onclick=>"alert('foo')"
        end.to_s.should == "<a href=\"http://example.com\" onclick=\"alert('foo')\">http://example.com</a>"
      end
    end

    describe '#capture' do
      it "should return content rather than write it to the buffer" do
        widget = Erector.inline do
          captured = capture do
            p 'Captured Content'
          end
          div do
            text captured
          end
        end
        widget.to_s.should == '<div><p>Captured Content</p></div>'
      end

      it "returns a RawString" do
        captured = nil
        Erector.inline do
          captured = capture {}
        end.to_s.should == ""
        captured.should be_a_kind_of Erector::RawString
      end

      it "works with nested captures" do
        widget = Erector.inline do
          captured = capture do
            captured = capture do
              p 'Nested Capture'
            end
            p 'Captured Content'
            text captured
          end
          div do
            text captured
          end
        end
        widget.to_s.should == '<div><p>Captured Content</p><p>Nested Capture</p></div>'
      end
    end

    describe 'nested' do
      it "can insert another widget without raw" do
        inner = Erector.inline do
          p "foo"
        end

        outer = Erector.inline do
          div inner
        end.to_s.should == '<div><p>foo</p></div>'
      end
    end

    describe '#write_via' do
      class A < Erector::Widget
        def content
          p "A"
        end
      end

      it "renders to a widget's doc" do
        class B < Erector::Widget
          def content
            text "B"
            A.new.write_via(self)
            text "B"
          end
        end
        b = B.new
        b.to_s.should == "B<p>A</p>B"
      end

      it "passing a widget to text method renders it" do
        Erector.inline do
          text "B"
          text A.new()
          text "B"
        end.to_s.should == "B<p>A</p>B"
      end

    end
    
    describe "assigning instance variables" do
      it "attempting to overwrite a reserved instance variable raises error" do
        lambda {
          Erector::Widget.new(:output => "foo")
        }.should raise_error(ArgumentError)
      end

      it "handles instance variable names with and without '@' in the beginning" do
        html = Erector.inline(:foo => "bar", '@baz' => 'quux') do
          div do
            p @foo
            p @baz
          end
        end.to_s
        doc = Nokogiri::HTML(html)
        doc.css("p").map {|p| p.inner_html}.should == ["bar", "quux"]
      end
    end
      
    context "when declaring parameters with the 'needs' macro" do
      it "doesn't complain if there aren't any needs declared" do
        class Thing1 < Erector::Widget
        end
        Thing1.new
      end
      
      it "allows you to say that you don't want any parameters" do
        class Thing2 < Erector::Widget
          needs nil
        end
        lambda { Thing2.new }.should_not raise_error
        lambda { Thing2.new(:foo => 1) }.should raise_error
      end
            
      it "doesn't complain if you pass it a declared parameter" do
        class Thing2b < Erector::Widget
          needs :foo
        end
        lambda { Thing2b.new(:foo => 1) }.should_not raise_error
      end
      
      it "complains if you pass it an undeclared parameter" do
        class Thing3 < Erector::Widget
          needs :foo
        end
        lambda { Thing3.new(:bar => 1) }.should raise_error
      end
      
      it "allows multiple declared parameters" do
        class Thing4 < Erector::Widget
          needs :foo, :bar
        end
        lambda { Thing4.new(:foo => 1, :bar => 2) }.should_not raise_error
      end
      
      it "complains when passing in an extra parameter after declaring many parameters" do
        class Thing5 < Erector::Widget
          needs :foo, :bar
        end
        lambda { Thing5.new(:foo => 1, :bar => 2, :baz => 3) }.should raise_error
      end
      
      it "complains when you forget to pass in a needed parameter" do
        class Thing6 < Erector::Widget
          needs :foo, :bar
        end
        lambda { Thing6.new(:foo => 1) }.should raise_error
      end
      
      it "doesn't complain if you omit a parameter with a default value" do
        class Thing7 < Erector::Widget
          needs :foo
          needs :bar => 7
          needs :baz => 8
        end
        lambda { 
          thing = Thing7.new(:foo => 1, :baz => 3) 
          thing.instance_variable_get(:@bar).should equal(7)
          thing.instance_variable_get(:@baz).should equal(3)
        }.should_not raise_error
      end
      
      it "allows multiple values on a line, including default values at the end of the line" do
        class Thing8 < Erector::Widget
          needs :foo, :bar => 7, :baz => 8
        end
        lambda { 
          thing = Thing8.new(:foo => 1, :baz => 2)
          thing.instance_variable_get(:@foo).should equal(1)
          thing.instance_variable_get(:@bar).should equal(7)
          thing.instance_variable_get(:@baz).should equal(2)
        }.should_not raise_error
      end
      
      it "allows nil to be a default value" do
        class Thing9 < Erector::Widget
          needs :foo => nil
        end
        lambda {
          thing = Thing9.new
          thing.instance_variable_get(:@foo).should be_nil
        }.should_not raise_error
      end
      
      it "accumulates needs across the inheritance chain even with modules mixed in" do
        module Something
        end

        class Vehicle < Erector::Widget
          needs :wheels
        end
        
        class Car < Vehicle
          include Something
          needs :engine
        end
        
        lambda { Car.new(:engine => 'V-8', :wheels => 4) }.should_not raise_error
        lambda { Car.new(:engine => 'V-8') }.should raise_error
        lambda { Car.new(:wheels => 4) }.should raise_error
      end
      
      it "no longer defines accessors for each of the needed variables" do
        class NeedfulThing < Erector::Widget
          needs :love
        end
        thing = NeedfulThing.new(:love => "all we need")
        lambda {thing.love}.should raise_error(NoMethodError)
      end
      
      it "no longer complains if you attempt to 'need' a variable whose name overlaps with an existing method" do
        class ThingWithOverlap < Erector::Widget
          needs :text
        end
        lambda { ThingWithOverlap.new(:text => "alas") }.should_not raise_error(ArgumentError)
      end
           
    end
    
    describe "#close_tag" do
      it "works when it's all alone, even though it messes with the indent level" do
        Erector.inline { close_tag :foo }.to_s.should == "</foo>"
        Erector.inline { close_tag :foo; close_tag :bar }.to_s.should == "</foo></bar>"
      end
    end
    
    describe "#dom_id" do
      class NiceWidget < Erector::Widget
        def content
          div :id => dom_id
        end
      end

      it "makes a unique id based on the widget's class name and object id" do
        widget = NiceWidget.new
        widget.dom_id.should include("#{widget.object_id}")
        widget.dom_id.should include("NiceWidget")
      end
      
      it "can be used as an HTML id" do
        widget = NiceWidget.new
        widget.to_s.should == "<div id=\"#{widget.dom_id}\"></div>"
      end
    end
  end
end
