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

    it "every word should be unique in its language", ', by using Word.new_uniqe_from_language' do
      delete_all_nodes_from Word, Language
      english = Language.new(:code => 'en')
      deutsch = Language.new(:code => 'de')

      # restart_transaction
      Word.to_a.size.should be 0
      Word.new_uniqe_from_language(:name => 'angst', :language => english)

      Word.to_a.size.should be 1

      first_english_kindergarten = Word.new_uniqe_from_language(:name => 'kindergarten', :language => english)

      Word.to_a.size.should be 2

      second_english_kindergarten = Word.new_uniqe_from_language(:name => 'kindergarten', :language => english)
      Word.to_a.size.should be 2
      first_english_kindergarten.should == second_english_kindergarten


      first_german_kindergarten = Word.new_uniqe_from_language(:name => 'kindergarten', :language => deutsch)
      Word.to_a.size.should be 3
      first_german_kindergarten.should_not == first_english_kindergarten
      first_german_kindergarten.should_not == second_english_kindergarten

      second_german_kindergarten = Word.new_uniqe_from_language(:name => 'kindergarten', :language => deutsch)
      Word.to_a.size.should be 3
      first_german_kindergarten.should == second_german_kindergarten
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
        @palace.rels.incoming(:words).to_a.should == @language.rels.outgoing(:words).to_a
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