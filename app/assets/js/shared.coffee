((d) ->
  a = d.getElementsByClassName('javascript-only')
  i = 0
  while i < a.length
    a[i].className = a[i].className.replace('javascript-only', '')
    ++i
  a = document.getElementsByTagName('noscript')
  i = 0
  while i < a.length
    (a[i].parentNode or a[i].parentElement).removeChild a[i]
    ++i
  return
) document