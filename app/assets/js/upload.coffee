$ ->
  input =
    magnet     : $('#textboxMagnet')
    file       : $('#fileTorrent')
    category   : $('#selectCategory')
    description: $('#textareaDescription')
  body = $('body')

  $('#formTorrent').submit (e) ->
    body.loading theme: 'dark', message: 'uploading...'