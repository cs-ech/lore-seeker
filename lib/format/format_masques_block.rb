class FormatMasquesBlock < Format
  def format_pretty_name
    "Masques Block"
  end

  def format_sets
    Set["mm", "ne", "pr"]
  end
end
