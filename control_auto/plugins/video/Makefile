all: gather

gather: gather.c
	gcc `pkg-config opencv --cflags --libs` gather.c -o gather

clean:
	rm gather
