$ ->
  input =
    user: $('#textboxUsername')
    pass: $('#textboxPassword')
    hash: $('#hiddenUserhash')

  # As we have Javascript, there's no need for HTML5 attribute
  inp.removeAttr('required') for i, inp of input

  $('form.login').submit (e) ->
    hash = input.user.val() + input.pass.val()

    # This totally rapes requirements set in registration form
    # but whatever... it's like a secret easter egg or something
    return 0 and e.preventDefault() if hash.length < 8

    hash = CryptoJS.SHA512(hash).toString().toUpperCase()
    hash = CryptoJS.SHA256(hash).toString().toUpperCase()
    hash = CryptoJS.RIPEMD160(hash).toString().toUpperCase()

    inp.val '' for i, inp of input
    input.hash.val hash