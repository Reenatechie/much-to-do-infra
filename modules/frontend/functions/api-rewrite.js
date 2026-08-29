// CloudFront Function, viewer-request, /api/* behaviour.
//
// The browser calls https://<domain>/api/auth/login, but the Go router only
// knows /auth/login. Strip the prefix before the request reaches the ALB.
function handler(event) {
    var request = event.request;
    var uri = request.uri;

    if (uri.indexOf('/api') === 0) {
        request.uri = uri.substring(4);
        if (request.uri === '') {
            request.uri = '/';
        }
    }

    return request;
}
