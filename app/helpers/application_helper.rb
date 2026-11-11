module ApplicationHelper
  ICONS = {
    "logo" => '<rect x="3" y="4" width="18" height="17" rx="3"/><path d="M3 9h18M8 2v4M16 2v4M8 14l2.5 2.5L16 12"/>',
    "sun" => '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
    "check" => '<rect x="3" y="3" width="18" height="18" rx="4"/><path d="M8 12l3 3 5-6"/>',
    "calendar" => '<rect x="3" y="4" width="18" height="17" rx="3"/><path d="M3 9h18M8 2v4M16 2v4"/>',
    "gear" => '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>',
    "repeat" => '<path d="M17 2l4 4-4 4"/><path d="M3 11V9a3 3 0 0 1 3-3h15M7 22l-4-4 4-4"/><path d="M21 13v2a3 3 0 0 1-3 3H3"/>',
    "clock" => '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    "pin" => '<path d="M12 21s-7-6.2-7-11a7 7 0 1 1 14 0c0 4.8-7 11-7 11z"/><circle cx="12" cy="10" r="2.5"/>',
    "trash" => '<path d="M3 6h18M8 6V4h8v2M6 6l1 15h10l1-15"/>'
  }.freeze

  def icon(name, size: 18)
    paths = ICONS[name.to_s] || ICONS["check"]
    %(<svg class="icon" width="#{size}" height="#{size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">#{paths}</svg>).html_safe
  end

  def nav_active?(path)
    path == "/" ? request.path == "/" : request.path.start_with?(path)
  end

  def priority_badge(task)
    return "".html_safe if task.priority.zero?
    tag.span(task.priority_name, class: "badge prio-#{task.priority_name}")
  end

  def due_label(task)
    return nil unless task.due_date
    today = Time.zone.today
    text = case task.due_date
    when today then "Today"
    when today + 1 then "Tomorrow"
    when today - 1 then "Yesterday"
    else task.due_date.year == today.year ? task.due_date.strftime("%a %b %-d") : task.due_date.strftime("%b %-d, %Y")
    end
    text += " #{format_clock(task.due_time)}" if task.due_time
    tag.span(text, class: "due #{'overdue' if task.overdue?}")
  end

  def format_clock(hhmm)
    Time.zone.parse("2000-01-01 #{hhmm}").strftime("%-l:%M %p")
  end

  def time_range(from, to, all_day: false)
    return "All day" if all_day
    "#{from.strftime('%-l:%M')}–#{to.strftime('%-l:%M %p')}"
  end

  def recurrence_options(current)
    presets = [ [ "Doesn't repeat", "" ], [ "Every day", "FREQ=DAILY" ], [ "Every weekday", "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR" ],
               [ "Every week", "FREQ=WEEKLY" ], [ "Every 2 weeks", "FREQ=WEEKLY;INTERVAL=2" ], [ "Every month", "FREQ=MONTHLY" ],
               [ "Every year", "FREQ=YEARLY" ] ]
    custom = current.present? && presets.none? { |_, v| v == current }
    options_for_select(presets + [ [ "Custom rule…", "custom" ] ], custom ? "custom" : current.to_s)
  end

  def recurrence_preset?(current)
    current.blank? || %w[FREQ=DAILY FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR FREQ=WEEKLY FREQ=WEEKLY;INTERVAL=2 FREQ=MONTHLY FREQ=YEARLY].include?(current)
  end

  def describe_recurrence(rule)
    {
      "FREQ=DAILY" => "Every day", "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR" => "Every weekday", "FREQ=WEEKLY" => "Every week",
      "FREQ=WEEKLY;INTERVAL=2" => "Every 2 weeks", "FREQ=MONTHLY" => "Every month", "FREQ=YEARLY" => "Every year"
    }.fetch(rule, rule)
  end
end
