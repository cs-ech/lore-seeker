class FormatPauper < FormatVintage
  def format_pretty_name
    "Pauper"
  end

  def in_format?(card)
    card.printings.each do |printing|
      next if @time and printing.release_date > @time
      next if @excluded_sets.include?(printing.set_code)
      next if printing.set.custom?
      return true if printing.rarity == "common" or printing.rarity == "basic"
    end
    false
  end
end
