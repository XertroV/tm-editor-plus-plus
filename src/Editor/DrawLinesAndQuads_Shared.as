namespace Editor {
    namespace DrawLinesAndQuads {
        // shared
        class DrawInstance {
            protected bool hasLines;
            protected bool hasQuads;
            protected vec3 linesColor = vec3(.5, .5, .5);
            protected vec3 quadsColor = vec3(.1, .1, .1);
            protected bool hasLinesColor = false;
            protected bool hasQuadsColor = false;
            protected uint drawExpiry = 0;
            protected bool active = false;
            protected bool deregister = false;

            protected bool updated = false;
            protected vec3[] lineVertices;
            protected vec3[] quadVertices;

            protected string id;

            DrawInstance(const string &in id) {
                this.id = id;
            }

            string get_Id() const {
                return id;
            }

            bool get_IsDeregistered() const {
                return deregister;
            }

            bool get_IsInactive() const {
                return !IsActive;
            }

            bool get_IsActive() const {
                return !deregister && (active || Time::Now < drawExpiry);
            }

            bool get_HasLines() const {
                return hasLines;
            }

            bool get_HasQuads() const {
                return hasQuads;
            }

            bool get_WasUpdated() const {
                return updated;
            }

            const array<vec3>@ get_LineVertices() const {
                return lineVertices;
                if (!IO::FolderExists(IO::FromStorageFolder("subfolder"))) {
                    IO::CreateFolder(IO::FromStorageFolder("subfolder"));
                }
            }

            const array<vec3>@ get_QuadVertices() const {
                return quadVertices;
            }

            vec3 get_LinesColor() const {
                return linesColor;
            }

            vec3 get_QuadsColor() const {
                return quadsColor;
            }

            bool get_HasLinesColor() const {
                return hasLinesColor;
            }

            bool get_HasQuadsColor() const {
                return hasQuadsColor;
            }

            void _AfterDraw() {
                updated = false;
            }

            // Call this each frame you want to draw the things. If you don't they will disappear after a frame (unless you've called DrawFor)
            bool Draw() {
                active = true;
                return !deregister;
            }

            // Set a minimum number of ms to keep this drawn for
            bool DrawFor(uint ms) {
                drawExpiry = Time::Now + ms;
                active = true;
                return !deregister;
            }

            // call this to never draw this object again
            void Deregister() {
                deregister = true;
            }

            // MARK: Line Segs

            // request that lines be drawn in this color (not guarenteed)
            void RequestLineColor(vec3 color) {
                linesColor = color;
                hasLinesColor = true;
            }

            int PushLineSegment(const vec3 &in a, const vec3 &in b) {
                hasLines = true;
                lineVertices.InsertLast(a);
                lineVertices.InsertLast(b);
                updated = true;
                return lineVertices.Length / 2 - 1;
            }

            void SetLineSegment(int i, const vec3 &in a, const vec3 &in b) {
                lineVertices[i * 2] = a;
                lineVertices[i * 2 + 1] = b;
                updated = true;
            }

            void SetLineSegmentsFromPath(const vec3[]@ points, int startAt = 0) {
                hasLines = true;
                lineVertices.Resize((points.Length - 1 + startAt) * 2);
                for (uint i = 0; i < points.Length - 1; i++) {
                    lineVertices[startAt + i * 2] = points[i];
                    lineVertices[startAt + i * 2 + 1] = points[i + 1];
                }
                updated = true;
            }

            void PushLineSegmentsFromPath(const vec3[]@ points) {
                auto startAt = lineVertices.Length / 2;
                SetLineSegmentsFromPath(points, startAt);
            }

            void GetLineSegment(int i, vec3 &out a, vec3 &out b) const {
                a = lineVertices[i * 2];
                b = lineVertices[i * 2 + 1];
            }

            void ResizeLineSegments(int newSize) {
                lineVertices.Resize(newSize * 2);
                updated = true;
            }

            void RemoveLineSegment(int i) {
                lineVertices.RemoveRange(i * 2, 2);
                updated = true;
            }

            void RemoveRangeLineSegments(int start, int count) {
                lineVertices.RemoveRange(start * 2, count * 2);
                updated = true;
            }

            int NbLineSegments() const {
                return lineVertices.Length / 2;
            }

            // MARK: Quads

            // Request quads be drawn in this color (not guarenteed)
            void RequestQuadColor(vec3 color) {
                quadsColor = color;
                hasQuadsColor = true;
            }

            int PushQuad(const vec3 &in a, const vec3 &in b, const vec3 &in c, const vec3 &in d) {
                hasQuads = true;
                quadVertices.InsertLast(a);
                quadVertices.InsertLast(b);
                quadVertices.InsertLast(c);
                quadVertices.InsertLast(d);
                updated = true;
                return quadVertices.Length / 4 - 1;
            }

            void SetQuad(int i, const vec3 &in a, const vec3 &in b, const vec3 &in c, const vec3 &in d) {
                quadVertices[i * 4] = a;
                quadVertices[i * 4 + 1] = b;
                quadVertices[i * 4 + 2] = c;
                quadVertices[i * 4 + 3] = d;
                updated = true;
            }

            void GetQuad(int i, vec3 &out a, vec3 &out b, vec3 &out c, vec3 &out d) const {
                a = quadVertices[i * 4];
                b = quadVertices[i * 4 + 1];
                c = quadVertices[i * 4 + 2];
                d = quadVertices[i * 4 + 3];
            }

            void ResizeQuads(int newSize) {
                quadVertices.Resize(newSize * 4);
                updated = true;
            }

            void RemoveQuad(int i) {
                quadVertices.RemoveRange(i * 4, 4);
                updated = true;
            }

            void RemoveRangeQuads(int start, int count) {
                quadVertices.RemoveRange(start * 4, count * 4);
                updated = true;
            }

            int NbQuads() const {
                return quadVertices.Length / 4;
            }
        }
    }
}
