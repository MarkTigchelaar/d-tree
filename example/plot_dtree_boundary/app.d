import std.stdio;


void plotSurface(Model, Xs, Ys)(Model model, Xs xs, Ys ys, size_t resolution=100) {
    import std.algorithm : map, cartesianProduct, minElement, maxElement;
    import std.array : array;
    import std.range : iota;

    import ggplotd.aes : aes;
    import ggplotd.geom : geomPolygon, geomPoint;
    import ggplotd.ggplotd : GGPlotD, putIn, title;
    import ggplotd.colour : colourGradient;
    import ggplotd.colourspace : XYZ;

    import mir.ndslice : ndarray, ndmap = map, pack;
    import numir : empty;

    const xmin = minElement(xs[0..$, 0]);
    const xmax = maxElement(xs[0..$, 0]);
    const ymin = minElement(xs[0..$, 1]);
    const ymax = maxElement(xs[0..$, 1]);
    const xstep = (xmax - xmin) / resolution;
    const ystep = (ymax - ymin) / resolution;

    double[][] gridArr = cartesianProduct(iota(xmin, xmax, xstep), iota(ymin, ymax, ystep)).map!"[a[0], a[1]]".array;
    auto grid = empty(gridArr.length, 2);
    foreach (i; 0 .. gridArr.length) {
        foreach (j; 0 .. 2) {
            grid[i, j] = gridArr[i][j];
        }
    }

    auto gridPreds = grid.pack!1.ndmap!(i => model.predict(i)[1]).ndarray;

    GGPlotD gg;

    gg = iota(grid.length)
        .map!(i => aes!("x", "y", "colour", "size", "fill")(grid[i][0], grid[i][1], gridPreds[i], 1.0, 0.1))
        .geomPoint
        .putIn(gg);

    gg = iota(xs.shape[0])
        .map!(i => aes!("x", "y", "colour", "size")(xs[i,0], xs[i,1], 0.5, 1.2))
        .geomPoint
        .putIn(gg);

    gg = iota(xs.shape[0])
        .map!(i => aes!("x", "y", "colour", "size")(xs[i,0], xs[i,1], ys[i] == 1 ? 1 : 0, 1.0))
        .geomPoint
        .putIn(gg);

    gg = colourGradient!XYZ( "cornflowerBlue-white-crimson" )
        .putIn(gg);

    gg.save("plot_dtree.png");
    writeln("saved to plot_dtree.png");
}

void main() {
    import mir.ndslice : map, slice, iota;
    import mir.random : Random, unpredictableSeed;
    import mir.random.variable : BernoulliVariable ;
    import numir.random : normal;
    import dtree.tree;

    auto nsamples = 200;
    auto ndim = 2;
    auto xs = normal(nsamples, ndim).slice;
    // TODO: add to numir.random
    auto gen = Random(unpredictableSeed);
    auto rv = BernoulliVariable!double(0.5);
    auto ys = iota(nsamples).map!(i => cast(long) rv(gen)).slice;
    foreach (i; 0 .. nsamples) {
        auto x = xs[i];
        auto y = ys[i];
        if (y == 1.0) {
            x[0] += 2.0;
            x[1] += 2.0;
        }
    }

    auto tree = makeCTree(xs, ys);
    tree.fit();
    // auto model = new BinarySVM!double(3, 0.1);
    // auto trainer = new SubgradientTrainer!(typeof(model))(model);
    // trainer.fit(xs, ys);
    plotSurface(tree, xs, ys);
}
