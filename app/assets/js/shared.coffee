#$ ->
#  # Display javascript only tags
#  $('.javascript-only').removeClass('javascript-only')
#
#  # Remove noscript tags for the lulz
#  $('noscript').remove()

#(function(d){
#	var a = d.getElementsByClassName('javascript-only');
#	for(var i=0; i<a.length; ++i){
#		a[i].className = a[i].className.replace('javascript-only', '');
#	}
#	a = document.getElementsByTagName('noscript');
#	for(i=0; i<a.length; ++i){
#		(a[i].parentNode || a[i].parentElement).removeChild(a[i]);
#	}
#})(document);
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