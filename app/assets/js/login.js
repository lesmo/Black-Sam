(function(){
	var i, inp, input;
	input = {
		user: id('textboxUsername'),
		pass: id('textboxPassword'),
		hash: id('hiddenUserhash')
	};
	for(i in input){
		input[i].removeAttribute('required');
	}
	elem('form.login').onsubmit = function(e){
		var hash;
		hash = input.user.value + input.pass.value;
		if (hash.length < 8) {
			return 0 && e.preventDefault();
		}
		hash = CryptoJS.SHA512(hash).toString().toUpperCase();
		hash = CryptoJS.SHA256(hash).toString().toUpperCase();
		hash = CryptoJS.RIPEMD160(hash).toString().toUpperCase();
		for(var i in input) {
			input[i].value = '';
		}
		return input.hash.value = hash;
	}
})();
