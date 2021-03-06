class Changeset::PullRequest
  # Common patterns
  CODE_ONLY = "[A-Z][A-Z\\d]+-\\d+"  # e.g., S4MS0N-123, SAM-456
  PUNCT = "\\s|\\p{Punct}|~|="

  # Matches a section heading named "Risks".
  RISKS_SECTION = /#+\s+Risks.*\n/i

  # Matches URLs to JIRA issues.
  JIRA_ISSUE_URL = %r[https?:\/\/[\da-z\.\-]+\.[a-z\.]{2,6}\/browse\/#{CODE_ONLY}(?=#{PUNCT}|$)]

  # Matches "VOICE-1234" or "[VOICE-1234]"
  JIRA_CODE_TITLE = %r[(\[)*(#{CODE_ONLY})(\])*]

  # Matches "VOICE-1234" only
  JIRA_CODE = %r[(?<=#{PUNCT}|^)(#{CODE_ONLY})(?=#{PUNCT}|$)]
  # Finds the pull request with the given number.
  #
  # repo   - The String repository name, e.g. "zendesk/samson".
  # number - The Integer pull request number.
  #
  # Returns a ChangeSet::PullRequest describing the PR or nil if it couldn't
  #   be found.
  def self.find(repo, number)
    data = Rails.cache.fetch([self, repo, number].join("-")) do
      GITHUB.pull_request(repo, number)
    end

    new(repo, data)
  rescue Octokit::NotFound
    nil
  end

  attr_reader :repo

  def initialize(repo, data)
    @repo, @data = repo, data
  end

  delegate :number, :title, :additions, :deletions, to: :@data

  def title_without_jira
    title.gsub(JIRA_CODE_TITLE, "").strip
  end

  def url
    "https://#{Rails.application.config.samson.github.web_url}/#{repo}/pull/#{number}"
  end

  def reference
    "##{number}"
  end

  def users
    users = [@data.user, @data.merged_by]
    users.compact.map {|user| Changeset::GithubUser.new(user) }.uniq
  end

  def risky?
    risks.present?
  end

  def risks
    return @risks if defined?(@risks)
    @risks = @data.body.to_s.split(RISKS_SECTION, 2)[1].to_s.strip.presence
    @risks = nil if @risks =~ /\A\s*\-?\s*None\Z/i
    @risks
  end

  def jira_issues
    @jira_issues ||= parse_jira_issues
  end

  private

  def parse_jira_issues
    custom_jira_url = ENV['JIRA_BASE_URL']
    title_and_body = "#{title} #{body}"
    jira_issue_map = {}
    if custom_jira_url
      title_and_body.scan(JIRA_CODE).each do |match|
        jira_issue_map[match[0]] = custom_jira_url + match[0]
      end
    end
    # explicit URLs should take precedence for issue links
    title_and_body.scan(JIRA_ISSUE_URL).each do |match|
      jira_issue_map[match.match(JIRA_CODE)[0]] = match
    end
    jira_issue_map.values.map { |x| Changeset::JiraIssue.new(x) }
  end

  def body
    @data.body.to_s
  end
end
