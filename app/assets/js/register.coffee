$ ->
  input =
    user : $('#textboxUsername')
    pass : $('#textboxPassword')
    pass2: $('#textboxPasswordRepeat')
    hash : $('#hiddenUserhash')

  error =
    user : $('#errorUsernameLength')
    pass : $('#errorPasswordLength')
    pass2: $('#errorPasswordMatch')

  # As we have Javascript, there's no need for HTML5 attribute
  inp.removeAttr('required') for i, inp of input

  $('form.register').submit (e) ->
    inp.parent().removeClass('has-error') for i, inp of input
    err.hide() for i, err of error

    if input.user.val().length < 8
      input.user.parent().addClass('has-error')
      error.user.slideDown()

    if input.pass.val().length < 8
      input.pass.parent().addClass('has-error')
      error.pass.slideDown()

    if input.pass.val() isnt input.pass2.val()
      input.pass2.parent().addClass('has-error')
      error.pass2.slideDown()

    if $(this).find('.has-error').length > 0
      return e.preventDefault()

    hash = input.user.val() + input.pass.val()
    hash = CryptoJS.SHA512(hash).toString().toUpperCase()
    hash = CryptoJS.SHA256(hash).toString().toUpperCase()
    hash = CryptoJS.RIPEMD160(hash).toString().toUpperCase()

    inp.val '' for i, inp of input
    input.hash.val hash