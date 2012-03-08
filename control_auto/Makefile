all: clVidFrame

clVidFrame: clVidFrame.c
	gcc `pkg-config opencv --cflags --libs` clVidFrame.c -o clVidFrame

clean:
	rm clVidFrame   
