a = 43071296928
b = 43050821171

c = a * 0.999022

print(b / a * 100)
print(c / a * 100)
print(abs(b - c) / min(b, c) * 100)
