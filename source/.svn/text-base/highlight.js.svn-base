function endsWith(str, suffix) {
  return str.indexOf(suffix, str.length - suffix.length) !== -1;
}

function swapHighlight(toset, tounset) {
  var el = document.getElementsByTagName('a');
  for (i = 0; i < el.length; i++) {
    if ((el[i].name == tounset) || endsWith(el[i].href, '#' + tounset)) {
      el[i].style.backgroundColor='';
    } 
    if ((el[i].name == toset) || endsWith(el[i].href, '#' + toset)) {
      el[i].style.backgroundColor='#FFFF80';
    }
  }
}

/* returns the ast path */
function extractAstPath(name) {
  pos = name.lastIndexOf('#');
  if (pos >= 0) {
    return name.substr(pos + 1, name.length - pos - 1);
  }
  return name;
}

var lastName = "";

function setup() {
  var el = document.getElementsByTagName('a');
  for (i = 0; i < el.length; i++) {
  	element = el[i];
    el[i].onmouseover = function(event) {
       	name = extractAstPath(this.name)
        if (name == "") {
        	name = extractAstPath(this.href)
        }
        swapHighlight(name, lastName);
        lastName = extractAstPath(name);
      }
  }
}
