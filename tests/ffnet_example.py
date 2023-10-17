from ffnet import ffnet, mlgraph, savenet, loadnet, exportnet
conec = mlgraph( (2,2,1) )
net = ffnet(conec)
input = [ [0.,0.], [0.,1.], [1.,0.], [1.,1.] ]
target  = [ [1.], [0.], [0.], [1.] ]
net.train_tnc(input, target, maxfun = 1000)
net.test(input, target, iprint = 2)
savenet(net, "xor.net")
exportnet(net, "xor.f")
net = loadnet("xor.net")
answer = net( [ 0., 0. ] )
partial_derivatives = net.derivative( [ 0., 0. ] )
