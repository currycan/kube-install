# kubelet-rubber-stamp

kubelet-rubber-stamp is simple CSR auto approver operator to help bootstrapping kubelet serving certificates easily.

The logic used follows the same logic used when auto-approving kubelet client certificates in kubelet TLS bootstrap phase.

So basically the flow is:

kubelet gets the client cert (see TLS bootstrap)
Kubelet creates a CSR
kubelet-rubber-stamp reacts to the creation of a CSR
validates that it's a valid request for kubelet serving certificate
validates that the requestor (the kubelet/node) has sufficient authorization
approve the CSR
Kubelet fetches the certificate
Kubelet auto-rotates certs, goto 2 :)
