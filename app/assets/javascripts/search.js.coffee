$(document).ready ->
  $('select#page_size, select#sort_by').on 'change', ->
    window.location.href = $(this).val()

  $('#searchBox').submit ->
    body_class = $('body').attr 'class'
    if $.trim($('#q').val()).length == 0
      !! (/timeline|map/.test(body_class) or window.is_refines_present)

