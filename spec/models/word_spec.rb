require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Word do
  before(:all) do
    start_neo4j
    Neo4j::Transaction.new
  end

  after(:all) do
    Neo4j::Transaction.finish
    stop_neo4j
  end

  describe "the word class" do
    it "should have some properties" do
      Word.properties?(:name).should be_true
    end
  end



  describe "a word instance" do
    describe "its relationship to a language instance" do
      before(:each) do
        delete_all_nodes_from Word, Language
        @palace   = Word.new(:name => 'palace')
        @language = Language.new(:code => 'en')

        @palace.language = @language
      end

      it "it should have relationship to a language" do
        @palace.language.should == @language
        @language.words.should include(@palace)
      end

      it "the relationships should be the same" do
        @palace.relationships.incoming(:words).to_a.should == @language.relationships.outgoing(:words).to_a
      end
    end



    describe "its relationship to a concept instance" do
      before(:each) do
        delete_all_nodes_from Word, Language
        @palace   = Word.new(:name => 'palace')
        @english  = Language.new(:code => 'en')

        @palast   = Word.new(:name => 'palast')
        @deutsch  = Language.new(:code => 'de')

        @palace.language = @english
        @palast.language = @deutsch

        @palace_concept = Concept.new
      end

      it "should have an relationship to a concept instance" do
        # @palace_concept.localized_names << @palast << @palace
        # @palace_concept.localized_names.should include(@palast, @palace)
      end
    end

  end
end