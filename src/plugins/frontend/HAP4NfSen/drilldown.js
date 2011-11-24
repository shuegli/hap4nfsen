var root = document.documentElement;

// enum used to represent the pressed mouse button
var MOUSE_BUTTON =
{
	LEFT:	0,
	MIDDLE:	1,
	RIGHT:	2
};

// add drill-down handlers
addDrilldownHandlers(root);

/**
 * returns the mouse button that caused the mouse event
 */
function getMouseButton(evt) {
	if (evt.which == null) { // internet explorer
		return ((evt.button < 2)?MOUSE_BUTTON.LEFT:((evt.button == 4)?MOUSE_BUTTON.MIDDLE:MOUSE_BUTTON.RIGHT));
	}
	// other browsers
	return ((evt.which < 2)?MOUSE_BUTTON.LEFT:((evt.which == 2)?MOUSE_BUTTON.MIDDLE:MOUSE_BUTTON.RIGHT));
}

/**
 * redirects the browser to a given url
 */
function redirect(url) {
	parent.document.location.href = url;
}

/**
 * disabes context menu
 */
function handleContextMenu() {
	return false;
}

/**
 * handles drilldown events(mouseup on a svg node with tagName 'a')
 */
function handleDrilldown(evt) {
	var pressed_button = getMouseButton(evt);
	switch(pressed_button)
	{
	case MOUSE_BUTTON.LEFT:
		redirect(this.getAttribute('standard_drilldown'));
		break;
	case MOUSE_BUTTON.RIGHT:
		redirect(this.getAttribute('part_desumm_drilldown'));
		break;
	case MOUSE_BUTTON.MIDDLE: // not used at the moment
		// redirect('http://www.google.com/search?q=middle mouse button');
		break;
	default: // not used at the moment
		// redirect('http://www.google.com/search?q=mouse with more than 3 buttons');
	}
}

/**
 * generates & returns the default drill-down url
 */
function getDefaultDrilldownLink(link) {
	return (link.getAttribute('xlink:href').replace(/&desum=\d+/, '')); //remove role id information from link
}

/**
 * generates and returns the drill-down link for partitial desummarization
 */
function getPartialDesummarizationDrilldownLink(link) {
	var param = link.getAttribute('xlink:href').match(/&desum=\d+/);
	if (param) {
		return link.getAttribute('xlink:href').replace(/&nodeid=.[kK_\d]+/, ''); // remove node id information from link
	}
	// no role number available -> use standard drill-down for both clicks
	return getDefaultDrilldownLink(link);
}

/**
 * finds all links in the svg document and adds drilldown support
 */
function addDrilldownHandlers(node) {
	var children = node.childNodes;
	for (var i = 0; i < children.length; i++){ 
		var child = children[i];
		addDrilldownHandlers(child);
		if (child.tagName == 'a') { // node is a link
			// add handlers
			child.onmouseup = handleDrilldown;
			child.oncontextmenu = handleContextMenu;
			// calculate and store both drill-down urls
			child.setAttribute('standard_drilldown', getDefaultDrilldownLink(child));
			child.setAttribute('part_desumm_drilldown', getPartialDesummarizationDrilldownLink(child));
			// remove existing link functionality
			child.removeAttribute('xlink:href');
			child.setAttribute("style", "cursor:pointer;");
		}
	} 
}
