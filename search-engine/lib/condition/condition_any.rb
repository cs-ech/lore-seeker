class ConditionAny < ConditionSimple
  def initialize(query)
    @query = query.downcase
    @subqueries = [
      ConditionWord.new(query),
      ConditionArtist.new(query),
      ConditionFlavor.new(query),
      ConditionOracle.new(query),
      ConditionTypes.new(query),
      ConditionForeign.new("foreign", query),
    ]
    case @query
    when "white"
      @subqueries << ConditionColorExpr.new("c", ">=", "w")
    when "blue"
      @subqueries << ConditionColorExpr.new("c", ">=", "u")
    when "black"
      @subqueries << ConditionColorExpr.new("c", ">=", "b")
    when "red"
      @subqueries << ConditionColorExpr.new("c", ">=", "r")
    when "green"
      @subqueries << ConditionColorExpr.new("c", ">=", "g")
    when "common", "uncommon", "rare", "mythic", "mythic rare", "special", "basic"
      @subqueries << ConditionRarity.new("=", @query)
    end
  end

  # This is going to be pretty slow
  def match?(card)
    @subqueries.any?{|sq| sq.match?(card)}
  end

  def to_s
    "any:#{maybe_quote(@query)}"
  end
end