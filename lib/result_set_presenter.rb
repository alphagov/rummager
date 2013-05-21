class ResultSetPresenter

  def initialize(result_set)
    @result_set = result_set
  end

  def present
    MultiJson.encode(results)
  end

  def present_with_total
    MultiJson.encode(
      total: @result_set.total,
      results: results
    )
  end

  PRESENTATION_FORMAT_TRANSLATION = {
    "planner" => "answer",
    "smart_answer" => "answer",
    "calculator" => "answer",
    "licence_finder" => "answer",
    "custom_application" => "answer",
    "calendar" => "answer"
  }

  FORMAT_NAME_ALTERNATIVES = {
    "programme" => "Benefits & credits",
    "transaction" => "Services",
    "local_transaction" => "Services",
    "place" => "Services",
    "answer" => "Quick answers",
    "specialist_guidance" => "Specialist guidance"
  }

private
  def presentation_format(document)
    normalized = normalized_format(document)
    PRESENTATION_FORMAT_TRANSLATION.fetch(normalized, normalized)
  end

  def humanized_format(document)
    presentation = presentation_format(document)
    FORMAT_NAME_ALTERNATIVES[presentation] || presentation.humanize.pluralize
  end

  def normalized_format(document)
    if document.format
      document.format.gsub("-", "_")
    else
      "unknown"
    end
  end

  def results
    @result_set.results.map { |r| r.to_hash.merge(
      presentation_format: presentation_format(r),
      humanized_format: humanized_format(r)
    )}
  end
end
