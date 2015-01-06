$ ->
  # As we have Javascript, there's no need for HTML5 attribute
  $('#textboxUsername').removeAttr('required')
  $('#textboxPassword').removeAttr('required')

  $('form.login').submit (e) ->
    hash = $('#textboxUsername').val() + $('#textboxPassword').val()

    if hash.length < 2
      return 0 and e.preventDefault()

    hash = CryptoJS.SHA512(hash).toString()
    hash = CryptoJS.SHA256(hash).toString()
    hash = CryptoJS.RIPEMD160(hash).toString()

    $('#hiddenUserhash').val hash
    $('#textboxUsername').val ''
    $('#textboxPassword').val ''