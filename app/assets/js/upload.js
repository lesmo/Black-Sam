id('formTorrent').onsubmit = function(){
	// i have no idea what .loading is, but it needs jquery
	$('body').loading({
		theme: 'dark',
		message: 'Uploading...'
	});
};
