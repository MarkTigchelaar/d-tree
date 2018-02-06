module dtree.tree;

import std.algorithm.comparison : min;
import std.stdio : writeln, writefln;

import mir.math : sum;
import mir.ndslice : ipack, unpack, ndmap = map;
import mir.ndslice.slice : sliced;
import mir.ndslice.allocation : ndarray;
import numir : ones, zeros, Ndim;

import dtree.impurity : gini, entropy;

struct RegressionTree {
    // not implemented
}

auto uniformProb(T=double)(size_t nClass) {
    return ndarray(ones!T(nClass) / nClass);
}


struct Node {
    size_t[] index;
    size_t depth = 0;
    double[] probs;

    size_t bestFeatId = 0;
    size_t bestSampleId = 0;
    double bestThreshold = 0;
    double bestImpurity = double.infinity;

    Node* left, right;

    @property
    const nElement() pure {
        return index.length;
    }

    @property
    const isLeaf() pure {
        return left is null && right is null;
    }

    auto born(size_t[] newIndex, double[] newProbs) {
        return new Node(newIndex,
                        this.depth + 1, newProbs);
    }

    void fit(Xs, Ys)(Xs xs, Ys ys, size_t nClass) {
        size_t[] lbestIndex, rbestIndex;
        auto lbestProbs = uniformProb(nClass);
        auto rbestProbs = uniformProb(nClass);

        foreach (sid; this.index) {
            auto x = xs[sid];
            // TODO support discrete feat
            for (size_t fid = 0; fid < x.length; ++fid) {
                auto threshold = x[fid];
                auto lprobs = zeros!double(nClass);
                auto rprobs = zeros!double(nClass);
                size_t[] lindex, rindex;
                foreach (i; this.index) {
                    if (xs[i][fid] > threshold) {
                        rindex ~= [i];
                        ++rprobs[ys[i]];
                    } else {
                        lindex ~= [i];
                        ++lprobs[ys[i]];
                    }
                }
                auto lsum = lprobs.sum!"fast";
                if (lsum > 0.0) {
                    lprobs[] /= lsum;
                }
                auto rsum = rprobs.sum!"fast";
                if (rsum > 0.0) {
                    rprobs[] /= rsum;
                }
                auto impurity = (gini(lprobs) * lindex.length +
                                 gini(rprobs) * rindex.length) / xs.length;
                // writeln("left: ", lprobs, "right: ", rprobs);
                if (impurity < this.bestImpurity) {
                    // TODO randomly update when impurity == this.bestImpurity
                    this.bestImpurity = impurity;
                    this.bestSampleId = sid;
                    this.bestFeatId = fid;
                    this.bestThreshold = threshold;
                    lbestIndex = lindex;
                    rbestIndex = rindex;
                    lbestProbs = lprobs.ndarray;
                    rbestProbs = rprobs.ndarray;
                }
            }
        }
        writefln("depth: %d, impurity: %f, probs: %s, L: %d, R: %d",
                 this.depth, this.bestImpurity, this.probs,
                 lbestIndex.length, rbestIndex.length);
        this.left = this.born(lbestIndex, lbestProbs);
        this.right = this.born(rbestIndex, rbestProbs);
    }

    auto predict(X)(X x) {
        if (this.isLeaf) { return this; }
        auto next = x[this.bestFeatId] > this.bestThreshold ? right : left;
        return next.predict(x);
    }
}

struct ClassificationTree {
    // Xs xs;
    // Ys ys;
    size_t nClass = 2;
    size_t maxDepth = 5;
    size_t minElement = 0;
    Node* root;

    auto fit(Xs, Ys)(Xs xs, Ys ys) {
        void fitrec(Node* node) {
            if (node.depth >= this.maxDepth || node.nElement <= this.minElement) return;
            node.fit(xs, ys, this.nClass);
            fitrec(node.left);
            fitrec(node.right);
        }

        import mir.ndslice : iota;
        auto points = iota(ys.length).ndarray;
        this.root = new Node(points, 0, this.nClass.uniformProb);
        fitrec(this.root);
    }

    auto predict(X)(X x) {
        return this.root.predict(x).probs;
    }
}
