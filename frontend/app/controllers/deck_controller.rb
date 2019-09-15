class DeckController < ApplicationController
  # We don't have any sensitive data, at some point might be good practice to enable it anyway
  skip_before_action :verify_authenticity_token

  def index
    @sets = $CardDatabase.sets.values.reject{|s| s.decks.empty?}.sort_by{|s| [-s.release_date.to_i_sort, s.name] }
    @custom_brawl_precons = DeckDatabase.new($CardDatabase).load_custom(Pathname("#{__dir__}/../../../data/crawl-precons.json"))
    @ech_precons = DeckDatabase.new($CardDatabase).load_custom(Pathname("#{__dir__}/../../../data/ech-precons.json"))
    @title = "Preconstructed Decks"
  end

  def download
    @set = $CardDatabase.sets[params[:set]] or return render_404
    @deck = @set.decks.find{|d| d.slug == params[:id]} or return render_404

    headers["Content-Disposition"] = "attachment; filename=#{@deck.name}.txt"
    render plain: @deck.to_text
  end

  def show
    @set = $CardDatabase.sets[params[:set]] or return render_404
    @deck = @set.decks.find{|d| d.slug == params[:id]} or return render_404

    @type = @deck.type
    @name = @deck.name
    @set_code = @set.code
    @set_name = @set.name
    @release_date = @deck.release_date

    @cards = @deck.cards.sort_by{|_,c| [c.name, c.set_code, c.number] }
    @sideboard = @deck.sideboard.sort_by{|_,c| [c.name, c.set_code, c.number] }

    @card_previews = @deck.physical_cards

    choose_default_preview_card
    group_cards

    @title = "#{@deck.name} - #{@set.name} #{@deck.type}"
  end

  def show_crawl
    @deck = DeckDatabase.new($CardDatabase).load_custom(Pathname("#{__dir__}/../../../data/crawl-precons.json")).find{|d| d.slug == params[:id]} or return render_404
    @set = @deck.set

    @type = @deck.type
    @name = @deck.name
    @set_code = @set.code
    @set_name = @set.name
    @release_date = @deck.release_date

    @cards = @deck.cards.sort_by{|_,c|
      c.is_a?(PhysicalCard) ? [0, c.name, c.set_code, c.number] : [1, c.name]
    }
    @sideboard = @deck.sideboard.sort_by{|_,c|
      c.is_a?(PhysicalCard) ? [0, c.name, c.set_code, c.number] : [1, c.name]
    }

    @legality = Format["custom brawl"].new.deck_legality(@deck)

    @card_previews = @deck.physical_cards.grep(PhysicalCard)

    choose_default_preview_card
    group_cards

    @title = "#{@deck.name} - #{@set.name} #{@deck.type}"
  end

  def show_ech
    @deck = DeckDatabase.new($CardDatabase).load_custom(Pathname("#{__dir__}/../../../data/ech-precons.json")).find{|d| d.slug == params[:id]} or return render_404
    @set = @deck.set

    @type = @deck.type
    @name = @deck.name
    @set_code = @set.code
    @set_name = @set.name
    @release_date = @deck.release_date

    @cards = @deck.cards.sort_by{|_,c|
      c.is_a?(PhysicalCard) ? [0, c.name, c.set_code, c.number] : [1, c.name]
    }
    @sideboard = @deck.sideboard.sort_by{|_,c|
      c.is_a?(PhysicalCard) ? [0, c.name, c.set_code, c.number] : [1, c.name]
    }

    @legality = Format["elder cockatrice highlander"].new.deck_legality(@deck)

    @card_previews = @deck.physical_cards.grep(PhysicalCard)

    choose_default_preview_card
    group_cards

    @title = "#{@deck.name} - #{@set.name} #{@deck.type}"
  end

  def visualize
    @title = "Deck Visualizer"
    @formats = Format.all_format_classes.map(&:new)
    @warnings = []

    if params[:deck_upload]
      @deck = params[:deck_upload].read
      parser = UserDeckParser.new(@deck)
      if parser.valid?
        @deck = parser.deck
      else
        @warnings.push("Can't parse uploaded deck.")
        @deck = ""
      end
    else
      @deck = params[:deck]
    end
    @format = params[:format] && Format[params[:format]].new

    if @deck.present?
      parser = DeckParser.new($CardDatabase, @deck)

      @cards = parser.deck.cards.sort_by{|_,c|
        c.is_a?(PhysicalCard) ? [0, c.name, c.set_code, c.number] : [1, c.name]
      }
      @sideboard = parser.deck.sideboard.sort_by{|_,c|
        c.is_a?(PhysicalCard) ? [0, c.name, c.set_code, c.number] : [1, c.name]
      }

      legality = @format.deck_legality(parser.deck)
      @warnings.push(legality) unless legality.nil?

      @card_previews = parser.deck.physical_cards.uniq.grep(PhysicalCard)

      choose_default_preview_card
      group_cards
    end
  end

  private

  def choose_default_preview_card
    # Choose best card to preview
    if @sideboard.size == 1 #TODO ECH
      # Commander
      @default_preview_card = @sideboard.first.last
    else
      @default_preview_card = @card_previews.min_by do |c|
        rarity = c.rarity
        types = c.main_front.types
        score = 0
        score += 10000 if rarity == "mythic"
        score += 1000 if rarity == "rare"
        score += 100 if types.include?("planeswalker")
        score += 10 if types.include?("legendary")
        score += 1 if types.include?("creature")
        [-score, c.name]
      end
    end
  end

  def group_cards
    @card_groups = @cards.group_by do |count, card|
      if card.is_a?(UnknownCard) or card.nil?
        [9, "Other"]
      else
        types = card.main_front.types
        if types.include?("creature")
          [1, "Creature"]
        elsif types.include?("land")
          [7, "Land"]
        elsif types.include?("planeswalker")
          [2, "Planeswalker"]
        elsif types.include?("instant")
          [3, "Instant"]
        elsif types.include?("sorcery")
          [4, "Sorcery"]
        elsif types.include?("artifact")
          [5, "Artifact"]
        elsif types.include?("enchantment")
          [6, "Enchantment"]
        else
          [8, "Other"]
        end
      end
    end
    unless @sideboard.empty?
      @card_groups[[9, "Sideboard"]] = @sideboard
    end
    @card_groups = @card_groups.sort
  end
end
