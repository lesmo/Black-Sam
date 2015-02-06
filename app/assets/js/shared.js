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

// http://caniuse.com/#search=queryselector
// https://i.imgur.com/LKkFH42.png
// Everything but IE 6-7 supports this
function id(id){ return document.getElementById(id); }
function elem(query){ return document.querySelector(query); }
function elems(query){ return document.querySelectorAll(query); }
