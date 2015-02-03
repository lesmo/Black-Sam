(function(d){
	var a = d.getElementsByClassName('javascript-only');
	for(var i=0; i<a.length; ++i){
		a[i].className = a[i].className.replace('javascript-only', '');
	}
	a = document.getElementsByTagName('noscript');
	for(i=0; i<a.length; ++i){
		(a[i].parentNode || a[i].parentElement).removeChild(a[i]);
	}
})(document);