// CloudFront Function, viewer-request, default behaviour.
//
// The React app uses client-side routing, so a hard refresh on /todos asks
// S3 for an object called "todos" that does not exist. Anything without a
// file extension is rewritten to index.html and React takes over from there.
function handler(event) {
    var request = event.request;
    var uri = request.uri;

    if (uri.charAt(uri.length - 1) === '/') {
        request.uri = '/index.html';
        return request;
    }

    var lastSegment = uri.substring(uri.lastIndexOf('/') + 1);
    if (lastSegment.indexOf('.') === -1) {
        request.uri = '/index.html';
    }

    return request;
}
