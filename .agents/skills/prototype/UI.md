# UI prototype

When the question concerns visual structure, show three distinct layouts by
default, not color variations. Use existing components and realistic synthetic
data density. Prefer an existing local page context; otherwise mark a throwaway
route clearly. A variant selector can use a URL parameter and visible controls;
keyboard switching must not intercept typing. Keep it out of production builds.
Use local stubs for mutations. Inspect each variation, gather the user's design
reaction, and record the preferred structure and why. Retain a reference to the
experiment, then implement the accepted design through the normal pipeline.
Do not add UI scaffolding when a render or CLI experiment answers the question.
