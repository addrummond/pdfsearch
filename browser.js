// Taken from http://www.quirksmode.org/js/cookies.html
function createCookie(name,value,days) {
    if (days) {
        var date = new Date();
        date.setTime(date.getTime()+(days*24*60*60*1000));
        var expires = "; expires="+date.toGMTString();
    }
    else var expires = "";
    document.cookie = name+"="+value+expires+"; path=/";
}

// As above.
function readCookie(name) {
    var nameEQ = name + "=";
    var ca = document.cookie.split(';');
    for(var i=0;i < ca.length;i++) {
        var c = ca[i];
        while (c.charAt(0)==' ') c = c.substring(1,c.length);
            if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
    }
    return null;
}

// As above.
function eraseCookie(name) {
    createCookie(name,"",-1);
}

// Cross-browser AJAX.
function getXMLHttpRequest()
{
    if (window.XMLHttpRequest) {
        return new XMLHttpRequest()
    }
    else if (window.ActiveXObject) {
        return new ActiveXObject("Microsoft.XMLHTTP")
    }
    else {
        return null;
    }
}

// Taken from http://aymanh.com/9-javascript-tips-you-may-not-know
function AssertException(message) { this.message = message; }
AssertException.prototype.toString = function () {
    return 'AssertException: ' + this.message;
}
function assert(exp, message) {
    if (! exp) {
        if (message)
            alert("ERROR: " + message);
        throw new AssertException(message);
    }
}
function assert_is_arraylike(expr, message) {
    assert((! (expr == null)) && typeof(expr.length) == "number", message)
}

function getDirJSON(dir, callback) {
    var xmlhttp = getXMLHttpRequest();
    var query = 'ajax_dirlist.pl?dir=' + escape(dir);
    xmlhttp.open('GET', query, true);
    xmlhttp.onreadystatechange = function () {
        if (xmlhttp.readyState == 4 && xmlhttp.status == 200) {
            var r = eval(xmlhttp.responseText);
            r.sort(function (x,y) { var a = x[1].toUpperCase(); var b = y[1].toUpperCase(); return (a===b) ? 0 : (a>b) ? 1 : -1; });
            callback(r)
        }
    }
    xmlhttp.send(null);
}

// Cross-browser.
function getEvent(e) {
    return e || window.event;
}

// Cross-browser.
function stop_event_propagating(e) {
    if (! e) var e = window.event;
    e.cancelBubble = true;
    if (e.stopPropagation) e.stopPropagation();
}

function prevent_default(e)
{
    if (e) e.preventDefault();
}

// Cross-browser fancy event adding (note that IE always uses bubbling, so no need to specify).
function listenToEvent(elem, name, func, capture)
{
    if (elem.addEventListener) {
        return elem.addEventListener(name, func, capture);
    }
    else {
        return elem.attachEvent("on" + name, func);
    }
}

var body = document.getElementsByTagName("body")[0];

function getNormalTextPxHeight()
{
    var x = document.createElement("div");
    x.style.visibility = "hidden";
    x.appendChild(document.createTextNode("AXpj"));
    body.appendChild(x);
    var h = x.offsetHeight;
    body.removeChild(x);
    return h;
}

function getNormalTextStringPxWidth(s)
{
    var x = document.createElement("span");
    x.style.visibility = "hidden";
    x.appendChild(document.createTextNode(s));
    body.appendChild(x);
    var w = x.offsetWidth;
    body.removeChild(x);
    return w;
}

function drawDir(path, tree, url_prefix, embedded, highlight) {
    assert_is_arraylike(tree);

    g_openDirs[path] = true;
    // This will cause there to be some unnecessary writing of cookies, but shouldn't
    // be an issue.
    createCookie("openDirs", escape(JSON.stringify(g_openDirs)), 2); 

    // Guaranteed to end with '/'
    full_url_prefix = url_prefix + (url_prefix.match(/\/$/) ? "" : "/") + (path.match(/^\//) ? path.substr(1) : path) + (path.match(/\/$/) ? "" : "/");

    var div = document.createElement("div");
    div.className = "dircontainer";

    var espan; // See below.

    function refresh (highlight) {
        getDirJSON(path, function(json) {
            var newdiv = drawDir(path, json, url_prefix, embedded, highlight);
            div.parentNode.replaceChild(newdiv, div);
        });
    }

    if (embedded) { // Don't want to allow uploading files to root dir (of course this must be disallowed on server side also).
        var upldiv = document.createElement("div");
        var a = document.createElement("a");
        a.href="";
        a.className = "diraction";
        a.innerHTML = "&raquo; upload a file to this folder.";
        upldiv.appendChild(a);

        var intid;
        var magic = new Date().getTime() + Math.random() + "";
        var up = new AjaxUpload(a, {
            action: "ajax_file_upload.pl",
            data: { "dir": path, "magic": magic},
            autoSubmit: true,
            responseType: false,
            onComplete: function(file, response) {
                clearInterval(intid);
                for (var i = 0; i < g_uploadTargetPaths.length; ++i) {
                    if (g_uploadTargetPaths[i] == path) {
                        g_uploadTargetPaths.splice(i, 1); // Remove the ith element.
                        break;
                    }
                }

                // Server sends a single newline if there was no error (this upload lib
                // seems not to make available the actual response code, so we can't check
                // for a 400).
                if (response && response.length > 1) {
                    // ERROR.
                    while (upldiv.childNodes.length > 1) upldiv.removeChild(upldiv.lastChild);
                    // Making it a table rather than a div because we don't want it splaying
                    // out all over the page (and IE doesn't support the relevant CSS property,
                    // of course).
                    espan = document.createElement("table"); // This is defined higher up.
                    var espantr = document.createElement("tr");
                    var espantd = document.createElement("td");
                    espan.appendChild(espantr);
                    espantr.appendChild(espantd);
                    espan.className = "uploaderror";
                    response = response.replace(/\$FILENAME/, '\u2018' + file + '\u2019');
                    espantd.appendChild(document.createTextNode(response));
                    upldiv.appendChild(espan);
                }
                else {
                    // FILE UPLOADED SUCCESSFULLY.
                    setTimeout(function () { refresh(file); }, 100);
                    if (upldiv.lastChild.tagName == "SPAN")
                        upldiv.removeChild(upldiv.lastChild);
                }
            },
            onSubmit: function(file, ext) {
                g_uploadTargetPaths.push(path);

                if (espan) {
                    upldiv.removeChild(espan);
                    espan = null;
                }

                intid = setInterval(function () {
                    var xmlhttp = getXMLHttpRequest();
                    var query = 'ajax_progress_check.pl?magic=' + escape(magic);
                    xmlhttp.open('GET', query, true);
                    var tries = 0;
                    xmlhttp.onreadystatechange = function() {
                        if (xmlhttp.readyState == 4) {
                            if (xmlhttp.status == 200) {
                                var pr = eval(xmlhttp.responseText);
                                if (upldiv.childNodes.length == 1) {
                                    var sp = document.createElement("span");
                                    sp.className = "uploadprogress";
                                    upldiv.appendChild(sp);
                                }
                                upldiv.lastChild.innerHTML = "&nbsp;&nbsp;" + parseInt(((pr[0] + 0.0) / (pr[1] + 0.0)) * 100.0) + "%";
                            }
                            else { /*alert("ERROR: " + xmlhttp.responseText);*/ ++tries; }
                            if (tries > 2)
                                clearInterval(intid);
                        } 
                    }
                    xmlhttp.send(null);

                    return true; // Don't cancel upload.
                }, 500);
            }
        });

        div.appendChild(upldiv);
    }

    var ul = document.createElement("ul");
    ul.className = "dirlist";
    div.appendChild(ul);

    for (var i = 0; i < tree.length; ++i) {
        (function (li, subdir) {

        ul.appendChild(li);
        if (! tree[i][0]) { // If it's a file.
            var a = document.createElement("a");
            a.className = "file";
            a.href = full_url_prefix + tree[i][1];
            a.appendChild(document.createTextNode(tree[i][1]));
            if (tree[i][1] == highlight) {
                a.className += " highlighted";
            }
            li.appendChild(a);
        }
        else {
            li.appendChild(document.createTextNode(tree[i][1]));
        }
        li.className = "node " + (tree[i][0] ? "dir" : "file");

        li.locked = false; // Ingore clicks while this is true (e.g. during loading).

        if (tree[i][0]) { // If it's a dir.
            function openitup() {
                 li.locked = true;

                 li.style.listStyleImage = "url('ajax-loader.gif')";
                 getDirJSON(subdir, function (json) {
                     var nul = drawDir(subdir, json, url_prefix, true);
                     li.open = true;
                     li.appendChild(nul);
                     li.className = "node opendir";
                     li.style.listStyleImage = "url('downarrow.png')";

                     li.locked = false;
                 });
            }

            // Is it open?
            li.open = g_openDirs[subdir];
            if (li.open) { openitup(); }

            listenToEvent(li, 'click', function(e) { // So we can specify event handling in the 'bubble' phase.
                if (li.locked) { return; }

                if (! li.open) {
                    openitup();
                }
                else {
                    // Don't allow the user to close this branch if there's a file being uploaded inside it.
                    var cantClose = false;
                    for (var i = 0; i < g_uploadTargetPaths.length; ++i) {
                        if (g_uploadTargetPaths[i].indexOf(path) == 0) {
                            cantClose = true; 
                            break;
                        }
                    }

                    if (cantClose) {
                        alert("You can't close this part of the tree because a file is being uploaded inside.");
                    }
                    else {

                    // The finicky bit -- we don't want the subtree to close wherever the user clicks within the
                    // li that isn't contained within a nested li (e.g. the blank space to the left). Unfortunately,
                    // we just have to look at the pixel position of the event to figure out whether or not this is
                    // the case.
                    var clickScreenX = getEvent(e).layerX || getEvent(e).offsetX; // I.E. doesn't support layerX/Y.
                    var clickScreenY = getEvent(e).layerY || getEvent(e).offsetY;
                    var liScreenY = li.offsetTop;
                    var linktext = li.firstChild.nodeValue; // The text in the text node.
                    var liScreenX = li.offsetLeft;
                    //alert(clickScreenX + ":" + clickScreenY + ", " + liScreenX + ":" + liScreenY + " - " + getNormalTextStringPxWidth(linktext));
                    if ((clickScreenY - liScreenY <= getNormalTextPxHeight()) && (clickScreenX < liScreenX + 25 + getNormalTextStringPxWidth(linktext))) {
                        //alert("HERE!");
                        for (var j = 0; j < li.childNodes.length; ++j) {
                            if (li.childNodes[j].tagName == "DIV" && li.childNodes[j].className == "dircontainer") {
                                li.removeChild(li.childNodes[j]);
                                li.open = false;
                                delete g_openDirs[subdir];
                                li.className = "node dir";
                                li.style.listStyleImage = "url('arrow.png')";
                            }
                        }
                    }

                    }
                }

                // Prevent the event from propagating (cross browser).
                stop_event_propagating(e);
            }, false); // False for 'bubble'.
        }
        else {
            // If it's a file, we just want to stop the event from propagating to the parent and closing it.
            listenToEvent(li, 'click', function(e) { stop_event_propagating(e); }, false); // False for 'bubble'.
        }

        })(document.createElement("li"), path + (path.match(/\/$/) ? '' : '/') + tree[i][1]);
    }

    return div;
}

if (readCookie("openDirs")) {
    g_openDirs = JSON.parse(unescape(readCookie("openDirs")));
}
else { g_openDirs = { }; }
g_uploadTargetPaths = [ ];

