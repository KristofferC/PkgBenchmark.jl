# Run a function after loading a REQUIREs file.
# Clean up afterwards
function with_reqs(f, reqs::AbstractString, pre=() -> nothing)
    if isfile(reqs)
        with_reqs(f, Pkg.Reqs.parse(reqs), pre)
    else
        f()
    end
end

function with_reqs(f, reqs::Dict, pre=() -> nothing)
    pre()
    cd(Pkg.dir()) do
        Pkg.Entry.resolve(merge(Pkg.Reqs.parse("REQUIRE"), reqs))
    end
    try
        f()
    catch
        rethrow()
    finally
        cd(Pkg.dir()) do
            Pkg.Entry.resolve()
        end
    end
end

# Run a function on a certain commit on the repo.
# Afterwards, go back to the previous commit or branch.
function with_commit(f, repo, commit)
    LibGit2.transact(repo) do r
        branch = try LibGit2.branch(r) catch err; nothing end
        prev = shastring(r, "HEAD")
        try
            LibGit2.checkout!(r, shastring(r, commit))
            f()
        catch err
            rethrow(err)
        finally
            if branch !== nothing
                LibGit2.branch!(r, branch)
            end
        end
    end
end

benchinfo(str) = print_with_color(Base.info_color(), STDOUT, "PkgBenchmark: ", str, "\n")
benchwarn(str) = print_with_color(Base.info_color(), STDOUT, "PkgBenchmark: ", str, "\n")